<script lang="ts">
  import { onMount, untrack } from 'svelte';
  import { portal } from '$lib/portal';
  import { notesStore } from '$lib/store/notes.svelte';
  import { workspacesStore } from '$lib/store/workspaces.svelte';
  import { profilesStore } from '$lib/store/profiles.svelte';
  import { api } from '$lib/api';
  import type { NoteCreateInput, NoteFilter, NoteScope } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import NotesList from './NotesList.svelte';
  import NoteEditor from './NoteEditor.svelte';
  import NoteFilters from './NoteFilters.svelte';
  import { t } from '$lib/i18n';

  interface Props {
    open?: boolean;
    context?: 'global' | 'workspace' | 'profile';
    contextId?: string;
    workspaceId?: string;
    openNoteId?: string | null;
  }

  let { open = $bindable(false), context = 'global', contextId, workspaceId, openNoteId = null }: Props = $props();

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

    return () => { /* watcher stays alive across panel opens */ };
  });

  $effect(() => {
    if (open) {
      untrack(() => notesStore.ensureLoaded());
      // Pre-set filter based on context
      if (context === 'workspace' && contextId) {
        activeFilter = { type: 'workspace', id: contextId };
      } else if (context === 'profile' && contextId) {
        activeFilter = { type: 'profile', id: contextId };
      } else {
        activeFilter = { type: 'all' };
      }
      // Open specific note if requested
      if (openNoteId && untrack(() => notesStore.activeNoteId) !== openNoteId) {
        void notesStore.openNote(openNoteId);
      }
    }
  });

  // Build NoteFilter from activeFilter state
  const noteFilter = $derived.by((): NoteFilter => {
    switch (activeFilter.type) {
      case 'global': return { scope: 'global' };
      case 'workspace': return { workspace_id: activeFilter.id };
      case 'profile': return { profile_id: activeFilter.id, scope: 'profile' };
      case 'tag': return { tag_name: activeFilter.id };
      case 'pinned': return { pinned: true };
      case 'archived': return { archived: true, include_deleted: false };
      default: return {};
    }
  });

  // Filtered + searched list
  const displayList = $derived.by(() => {
    let list = notesStore.list;

    // Apply activeFilter
    if (activeFilter.type !== 'all') {
      if (activeFilter.type === 'global') list = list.filter((n) => n.scope === 'global' && !n.archived);
      else if (activeFilter.type === 'workspace') list = list.filter((n) => n.workspace_id === activeFilter.id && !n.archived);
      else if (activeFilter.type === 'profile') list = list.filter((n) => n.profile_id === activeFilter.id && !n.archived);
      else if (activeFilter.type === 'tag') list = list.filter((n) => n.tags.some((t) => t.name === activeFilter.id) && !n.archived);
      else if (activeFilter.type === 'pinned') list = list.filter((n) => n.pinned && !n.archived);
      else if (activeFilter.type === 'archived') list = list.filter((n) => n.archived);
    } else {
      list = list.filter((n) => !n.archived);
    }

    // Search filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      list = list.filter(
        (n) =>
          n.title.toLowerCase().includes(q) ||
          n.tags.some((t) => t.name.toLowerCase().includes(q))
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
      // Merge results into display (search replaces local filter)
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

  async function handleFilterChange(f: { type: string; id?: string }) {
    activeFilter = f;
    searchQuery = '';
    await notesStore.refresh();
  }

  async function createNote() {
    if (!createTitle.trim()) return;

    // Determine scope from active filter first, fallback to context prop
    let scope: NoteScope = 'global';
    let create_workspace_id: string | undefined;
    let create_profile_id: string | undefined;

    if (activeFilter.type === 'workspace' && activeFilter.id) {
      scope = 'workspace';
      create_workspace_id = activeFilter.id;
    } else if (activeFilter.type === 'profile' && activeFilter.id) {
      scope = 'profile';
      create_profile_id = activeFilter.id;
      create_workspace_id = workspaceId;
    } else if (context === 'workspace' && contextId) {
      scope = 'workspace';
      create_workspace_id = contextId;
    } else if (context === 'profile' && contextId) {
      scope = 'profile';
      create_profile_id = contextId;
      create_workspace_id = workspaceId;
    }
    // 'global', 'all', 'pinned', 'archived' → scope stays 'global'

    const input: NoteCreateInput = {
      title: createTitle.trim(),
      format: createFormat,
      scope,
      workspace_id: create_workspace_id,
      profile_id: create_profile_id,
    };

    try {
      const note = await notesStore.createNote(input);
      showCreate = false;
      createTitle = '';
      await notesStore.openNote(note.id);
    } catch {}
  }

  async function handleSelectNote(id: string) {
    await notesStore.openNote(id);
  }

  function onKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      if (showCreate) showCreate = false;
      else open = false;
    }
  }

  function workspaceName(id: string): string {
    return workspacesStore.list.find((w) => w.id === id)?.name ?? id;
  }

  function profileName(id: string): string {
    return profilesStore.list.find((p) => p.id === id)?.name ?? id;
  }
</script>

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
  <div
    class="overlay"
    use:portal
    onclick={(e) => { if (e.target === e.currentTarget) open = false; }}
    onkeydown={onKeydown}
    role="presentation"
    tabindex="-1"
  >
    <div class="panel" role="dialog" aria-label={$t('notes_title')}>
      <!-- Header -->
      <div class="panel-header">
        <div class="header-title">
          <Icon name="file-text" size={16} />
          <h3>{$t('notes_title')}</h3>
          <span class="count-badge">{displayList.length}</span>
        </div>
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
          <button class="close-btn" onclick={() => (open = false)}>
            <Icon name="x" size={15} />
          </button>
        </div>
      </div>

      <!-- Search -->
      <div class="panel-search">
        <div class="search-wrap">
          <span class="search-icon"><Icon name="search" size={13} /></span>
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

      <!-- Body: sidebar + list + editor -->
      <div class="panel-body">
        {#if sidebarVisible}
          <div class="sidebar">
            <NoteFilters
              notes={notesStore.list}
              allTags={notesStore.allTags}
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
            />
          </div>
        </div>

        <div class="editor-col">
          <NoteEditor allTags={notesStore.allTags} />
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
              class="create-title"
              onkeydown={(e) => e.key === 'Enter' && createNote()}
            />
            <div class="create-actions">
              <button class="btn-ghost" onclick={() => (showCreate = false)}>{$t('notes_btn_cancel')}</button>
              <button class="btn-primary" onclick={createNote} disabled={!createTitle.trim()}>
                {$t('notes_btn_create')}
              </button>
            </div>
          </div>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.3);
    z-index: 900;
    display: flex;
    justify-content: flex-end;
  }

  .panel {
    background: var(--bg-2);
    border-left: 1px solid var(--border);
    width: min(900px, 96vw);
    height: 100%;
    display: flex;
    flex-direction: column;
    box-shadow: var(--shadow-lg);
    animation: slide-in 0.2s ease;
    position: relative;
  }

  @keyframes slide-in {
    from { transform: translateX(100%); }
    to { transform: translateX(0); }
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.85rem 1.25rem;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .header-title {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .header-title h3 {
    margin: 0;
    font-size: 0.95rem;
    font-weight: 600;
  }

  .count-badge {
    background: var(--accent-bg);
    color: var(--accent);
    border: 1px solid var(--accent);
    border-radius: 999px;
    font-size: 0.7rem;
    padding: 0.05rem 0.4rem;
    font-weight: 600;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 0.2rem;
  }

  .icon-btn, .close-btn {
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

  .icon-btn:hover, .close-btn:hover { color: var(--text); background: var(--surface); }

  .panel-search {
    padding: 0.6rem 1rem 0;
    flex-shrink: 0;
  }

  .search-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }

  .search-icon {
    position: absolute;
    left: 0.6rem;
    color: var(--text-2);
    pointer-events: none;
    display: flex;
  }

  .search-input {
    width: 100%;
    box-sizing: border-box;
    padding: 0.42rem 0.6rem 0.42rem 2rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--text);
    font-size: 0.83rem;
  }

  .search-input:focus { outline: none; border-color: var(--accent); }

  .search-spinner {
    position: absolute;
    right: 0.6rem;
    color: var(--accent);
    display: flex;
    animation: spin 1s linear infinite;
  }

  @keyframes spin { to { transform: rotate(360deg); } }

  .panel-body {
    flex: 1;
    display: flex;
    overflow: hidden;
    margin-top: 0.5rem;
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
    padding: 0.4rem 0.5rem;
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
  }

  .btn-new {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
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
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
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

  .create-title {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.45rem 0.75rem;
    color: var(--text);
    font-size: 0.88rem;
    width: 100%;
    box-sizing: border-box;
  }

  .create-title:focus { outline: none; border-color: var(--accent); }

  .create-row {
    display: flex;
    gap: 0.5rem;
  }

  .create-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
  }

  .btn-primary {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: var(--radius-sm);
    padding: 0.4rem 0.9rem;
    font-size: 0.83rem;
    cursor: pointer;
    transition: background 0.15s;
  }

  .btn-primary:hover:not(:disabled) { background: var(--accent-hover); }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .btn-ghost {
    background: none;
    color: var(--text-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.4rem 0.9rem;
    font-size: 0.83rem;
    cursor: pointer;
    transition: all 0.15s;
  }

  .btn-ghost:hover { border-color: var(--border-2); color: var(--text); }
</style>
