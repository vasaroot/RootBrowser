<script lang="ts">
  import { onMount } from 'svelte';
  import { notesStore } from '$lib/store/notes.svelte';
  import { workspacesStore } from '$lib/store/workspaces.svelte';
  import { profilesStore } from '$lib/store/profiles.svelte';
  import { api } from '$lib/api';
  import type { NoteCreateInput, NoteFilter } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import NotesList from '$lib/components/notes/NotesList.svelte';
  import NoteEditor from '$lib/components/notes/NoteEditor.svelte';
  import NoteFilters from '$lib/components/notes/NoteFilters.svelte';
  import { t } from '$lib/i18n';

  let searchQuery = $state('');
  let searching = $state(false);
  let showCreate = $state(false);
  let createTitle = $state('');
  let createFormat = $state<string>('txt');
  let activeFilter = $state<{ type: string; id?: string }>({ type: 'all' });
  let sidebarVisible = $state(true);

  onMount(() => {
    notesStore.ensureLoaded();
    workspacesStore.ensureLoaded();
    profilesStore.ensureLoaded();
    notesStore.startWatcher();
  });

  const noteFilter = $derived.by((): NoteFilter => {
    switch (activeFilter.type) {
      case 'workspace': return { binding: `workspace:${activeFilter.id}` };
      case 'profile':   return { binding: `profile:${activeFilter.id}` };
      case 'tag':       return { tag_name: activeFilter.id };
      case 'pinned':    return { pinned: true };
      case 'archived':  return { archived: true, include_deleted: false };
      default:          return {};
    }
  });

  const displayList = $derived.by(() => {
    let list = notesStore.list;

    if (activeFilter.type !== 'all') {
      if (activeFilter.type === 'global')
        list = list.filter((n) => !n.bindings.some((b: string) => b.startsWith('workspace:') || b.startsWith('profile:')) && !n.archived);
      else if (activeFilter.type === 'workspace')
        list = list.filter((n) => n.bindings.includes(`workspace:${activeFilter.id}`) && !n.archived);
      else if (activeFilter.type === 'profile')
        list = list.filter((n) => n.bindings.includes(`profile:${activeFilter.id}`) && !n.archived);
      else if (activeFilter.type === 'tag')
        list = list.filter((n) => n.tags.some((tg: { name: string }) => tg.name === activeFilter.id) && !n.archived);
      else if (activeFilter.type === 'tag-group')
        list = list.filter((n) => n.tags.some((tg: { name: string }) => tg.name === activeFilter.id || tg.name.startsWith(activeFilter.id + '/')) && !n.archived);
      else if (activeFilter.type === 'folder') {
        const ids = folderDescendantIds(activeFilter.id!);
        list = list.filter((n) => n.folder_ids.some(fid => ids.has(fid)) && !n.archived);
      }
      else if (activeFilter.type === 'pinned')
        list = list.filter((n) => n.pinned && !n.archived);
      else if (activeFilter.type === 'archived')
        list = list.filter((n) => n.archived);
    } else {
      list = list.filter((n) => !n.archived);
    }

    // Локальный фильтр только для 1 символа (< 2 не вызывает API)
    if (searchQuery.trim().length === 1) {
      const q = searchQuery.toLowerCase();
      list = list.filter(
        (n) =>
          n.title.toLowerCase().includes(q) ||
          n.tags.some((tg: { name: string }) => tg.name.toLowerCase().includes(q)) ||
          n.folder_ids.some(fid => notesStore.folders.find(f => f.id === fid)?.name.toLowerCase().includes(q))
      );
    }

    return list;
  });

  async function handleSearch() {
    if (!searchQuery.trim()) {
      await notesStore.refresh();
      return;
    }
    searching = true;
    try {
      const results = await api.notes.search(searchQuery, noteFilter);
      notesStore.list = results;
    } catch {}
    finally { searching = false; }
  }

  let searchTimer: ReturnType<typeof setTimeout> | null = null;
  function onSearchInput() {
    if (searchTimer) clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      if (searchQuery.trim().length >= 2) void handleSearch();
      else void notesStore.refresh();
    }, 350);
  }

  $effect(() => {
    if (notesStore.activeNoteId && !displayList.some(n => n.id === notesStore.activeNoteId)) {
      notesStore.activeNoteId = null;
      notesStore.activeNote = null;
    }
  });

  async function handleFilterChange(f: { type: string; id?: string }) {
    activeFilter = f;
    searchQuery = '';
    await notesStore.refresh();
  }

  async function createNote() {
    if (!createTitle.trim()) return;

    const bindings: string[] = [];
    if (activeFilter.type === 'workspace' && activeFilter.id)
      bindings.push(`workspace:${activeFilter.id}`);
    else if (activeFilter.type === 'profile' && activeFilter.id)
      bindings.push(`profile:${activeFilter.id}`);

    const input: NoteCreateInput = {
      title: createTitle.trim(),
      format: createFormat,
      bindings,
    };
    try {
      const note = await notesStore.createNote(input);

      if (activeFilter.type === 'folder' && activeFilter.id) {
        await api.notes.noteAddFolder(note.id, activeFilter.id);
        await notesStore.refresh();
      }

      showCreate = false;
      createTitle = '';
      await notesStore.openNote(note.id);
    } catch {}
  }

  async function handleSelectNote(id: string) {
    await notesStore.openNote(id);
  }

  function workspaceName(id: string): string {
    return workspacesStore.list.find((w) => w.id === id)?.name ?? id;
  }

  function profileName(id: string): string {
    return profilesStore.list.find((p) => p.id === id)?.name ?? id;
  }

  function folderName(id: string): string {
    return notesStore.folders.find((f) => f.id === id)?.name ?? id;
  }

  function folderDescendantIds(folderId: string): Set<string> {
    const result = new Set<string>([folderId]);
    for (const f of notesStore.folders) {
      if (f.parent_id === folderId) {
        for (const id of folderDescendantIds(f.id)) result.add(id);
      }
    }
    return result;
  }

  function folderColor(id: string): string {
    return notesStore.folders.find((f) => f.id === id)?.color ?? 'var(--text-2)';
  }
</script>

<div class="notes-page">
  <!-- Header -->
  <div class="page-header">
    <h1>{$t('notes_title')}</h1>
    <div class="header-actions">
      <button class="icon-btn" title={$t('notes_btn_sync')} onclick={() => api.notes.sync()}>
        <Icon name="refresh-cw" size={13} />
      </button>
      <button class="icon-btn" title={$t('notes_btn_open_folder')} onclick={() => api.notes.openFolder()}>
        <Icon name="folder-open" size={13} />
      </button>
      <button class="icon-btn" onclick={() => { sidebarVisible = !sidebarVisible; }} title={$t('notes_btn_toggle_sidebar')}>
        <Icon name="sidebar" size={13} />
      </button>
    </div>
  </div>

  <!-- Search -->
  <div class="toolbar">
    <div class="search-wrap">
      <Icon name="search" size={13} />
      <input
        type="text"
        bind:value={searchQuery}
        oninput={onSearchInput}
        placeholder={$t('notes_search_placeholder')}
        class="search-input"
      />
      {#if searching}
        <span class="search-spinner"><Icon name="loader" size={12} /></span>
      {/if}
    </div>
  </div>

  <!-- Body -->
  <div class="page-body">
    {#if sidebarVisible}
      <div class="sidebar">
        <NoteFilters
          notes={notesStore.list}
          allTags={notesStore.allTags}
          folders={notesStore.folders}
          {activeFilter}
          onfilter={handleFilterChange}
        />
      </div>
    {/if}

    <div class="list-col">
      <div class="list-header">
        <button class="btn-new" onclick={() => (showCreate = true)}>
          <Icon name="plus" size={12} /> {$t('notes_btn_new')}
        </button>
      </div>
      <div class="list-scroll">
        <NotesList
          notes={displayList}
          activeId={notesStore.activeNoteId}
          onselect={handleSelectNote}
          oncreate={() => (showCreate = true)}
          {workspaceName}
          {profileName}
          {folderName}
          {folderColor}
        />
      </div>
    </div>

    <div class="editor-col">
      <NoteEditor allTags={notesStore.allTags} folders={notesStore.folders} />
    </div>
  </div>
</div>

<!-- Create modal -->
{#if showCreate}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
  <div class="create-overlay" onclick={(e) => { if (e.target === e.currentTarget) showCreate = false; }} role="presentation">
    <div class="create-card">
      <h4>{$t('notes_create_title')}</h4>
      <input
        type="text"
        bind:value={createTitle}
        placeholder={$t('notes_title_placeholder')}
        onkeydown={(e) => e.key === 'Enter' && createNote()}
      />
      <div class="create-actions">
        <button class="btn btn-ghost" onclick={() => (showCreate = false)}>{$t('notes_btn_cancel')}</button>
        <button class="btn btn-primary" onclick={createNote} disabled={!createTitle.trim()}>
          {$t('notes_btn_create')}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .notes-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    overflow: hidden;
    gap: 0.875rem;
  }

  .page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
  }

  h1 { font-size: 1.4rem; font-weight: 700; letter-spacing: -0.02em; }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 0.2rem;
  }

  .icon-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-2);
    display: flex;
    align-items: center;
    padding: 0.25rem;
    border-radius: var(--radius-sm);
    transition: all 0.15s;
  }

  .icon-btn:hover { color: var(--text); background: var(--surface); }

  .toolbar {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    flex-shrink: 0;
  }

  .search-wrap {
    position: relative;
    display: flex;
    align-items: center;
    width: 260px;
    flex-shrink: 0;
  }

  .search-wrap :global(svg) {
    position: absolute;
    left: 0.55rem;
    color: var(--text-3);
    pointer-events: none;
  }

  .search-input {
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    width: 100%;
    padding: 0 1.75rem 0 2rem;
    font-size: 0.8rem;
    height: 32px;
    outline: none;
    transition: border-color 0.15s;
  }

  .search-input:focus { border-color: var(--accent); }

  .search-spinner {
    position: absolute;
    right: 0.5rem;
    color: var(--accent);
    display: flex;
    animation: spin 1s linear infinite;
  }

  @keyframes spin { to { transform: rotate(360deg); } }

  .page-body {
    flex: 1;
    display: flex;
    overflow: hidden;
    border: 1px solid var(--border);
    min-height: 0;
    border-radius: var(--radius);
  }

  .sidebar {
    width: 180px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    overflow-y: auto;
  }

  .list-col {
    width: 240px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .list-header {
    height: 40px;
    padding: 0 0.5rem;
    display: flex;
    align-items: center;
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
  }

  .btn-new {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    margin-left: auto;
    background: none;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.25rem 0.6rem;
    font-size: 0.78rem;
    color: var(--text-2);
    cursor: pointer;
    transition: all 0.15s;
  }

  .btn-new:hover { border-color: var(--accent); color: var(--accent); }

  .list-scroll {
    flex: 1;
    overflow-y: auto;
    padding: 0.5rem;
  }

  .editor-col {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
  }

  /* Create modal */
  .create-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 200;
  }

  .create-card {
    background: var(--bg-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1.25rem;
    width: 320px;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    box-shadow: var(--shadow-lg);
  }

  .create-card h4 {
    margin: 0;
    font-size: 0.95rem;
    font-weight: 600;
  }

  .create-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
  }
</style>
