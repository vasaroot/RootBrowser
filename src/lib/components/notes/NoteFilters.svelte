<script lang="ts">
  import type { NoteListItem, NoteTag } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import { workspacesStore } from '$lib/store/workspaces.svelte';
  import { profilesStore } from '$lib/store/profiles.svelte';
  import { notesStore } from '$lib/store/notes.svelte';
  import { t } from '$lib/i18n';

  interface TagGroup {
    name: string;
    color: string;
    count: number;
  }

  interface Props {
    notes: NoteListItem[];
    allTags: NoteTag[];
    activeFilter: { type: string; id?: string };
    onfilter: (filter: { type: string; id?: string }) => void;
  }

  let { notes, allTags, activeFilter, onfilter }: Props = $props();

  // Collapsed workspace nodes
  let collapsedWs = $state<Set<string>>(new Set());
  let showNewArea = $state(false);
  let newAreaName = $state('');
  let newAreaColor = $state('#6366f1');
  let creating = $state(false);

  function toggleWs(id: string) {
    const next = new Set(collapsedWs);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    collapsedWs = next;
  }

  const countAll = $derived(notes.filter((n) => !n.archived).length);
  const countGlobal = $derived(notes.filter((n) => n.scope === 'global' && !n.archived).length);
  const countPinned = $derived(notes.filter((n) => n.pinned && !n.archived).length);
  const countArchived = $derived(notes.filter((n) => n.archived).length);

  // Merge allTags with counts from notes
  const tagGroups = $derived.by((): TagGroup[] => {
    const countMap = new Map<string, number>();
    for (const note of notes) {
      if (note.archived) continue;
      for (const tag of note.tags) {
        countMap.set(tag.name, (countMap.get(tag.name) ?? 0) + 1);
      }
    }
    return allTags
      .map((t) => ({ name: t.name, color: t.color, count: countMap.get(t.name) ?? 0 }))
      .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
  });

  // Workspace tree
  const workspaceTree = $derived.by(() => {
    return workspacesStore.list.map((ws) => {
      const wsNotes = notes.filter((n) => n.workspace_id === ws.id && n.scope === 'workspace' && !n.archived);
      const profiles = profilesStore.byWorkspace(ws.id).map((p) => {
        const pNotes = notes.filter((n) => n.profile_id === p.id && !n.archived);
        return { ...p, noteCount: pNotes.length };
      }).filter((p) => p.noteCount > 0);
      return { ...ws, noteCount: wsNotes.length, profiles };
    }).filter((ws) => ws.noteCount > 0 || ws.profiles.length > 0);
  });

  function isActive(type: string, id?: string) {
    return activeFilter.type === type && activeFilter.id === id;
  }

  function filterClass(type: string, id?: string) {
    return isActive(type, id) ? 'nav-item active' : 'nav-item';
  }

  async function createArea() {
    if (!newAreaName.trim() || creating) return;
    creating = true;
    try {
      const tag = await notesStore.createTag(newAreaName.trim(), newAreaColor);
      showNewArea = false;
      newAreaName = '';
      newAreaColor = '#6366f1';
      onfilter({ type: 'tag', id: tag.name });
    } finally {
      creating = false;
    }
  }
</script>

<div class="filters">
  <div class="filter-section">
    <button class={filterClass('all')} onclick={() => onfilter({ type: 'all' })}>
      <Icon name="file-text" size={13} />
      {$t('notes_filter_all')}
      <span class="count">{countAll}</span>
    </button>
    <button class={filterClass('global')} onclick={() => onfilter({ type: 'global' })}>
      <Icon name="globe" size={13} />
      {$t('notes_filter_global')}
      <span class="count">{countGlobal}</span>
    </button>
    <button class={filterClass('pinned')} onclick={() => onfilter({ type: 'pinned' })}>
      <Icon name="pin" size={13} />
      {$t('notes_filter_pinned')}
      <span class="count">{countPinned}</span>
    </button>
    <button class={filterClass('archived')} onclick={() => onfilter({ type: 'archived' })}>
      <Icon name="archive" size={13} />
      {$t('notes_filter_archived')}
      <span class="count">{countArchived}</span>
    </button>
  </div>

  {#if workspaceTree.length > 0}
    <div class="filter-section">
      <div class="section-label">{$t('notes_filter_workspaces')}</div>
      {#each workspaceTree as ws (ws.id)}
        <div class="ws-node">
          <div class="ws-node-row">
            <button
              class="{filterClass('workspace', ws.id)} ws-item"
              onclick={() => onfilter({ type: 'workspace', id: ws.id })}
            >
              <span class="ws-dot" style="background:{ws.color}"></span>
              <span class="ws-name">{ws.name}</span>
              {#if ws.noteCount > 0}
                <span class="count">{ws.noteCount}</span>
              {/if}
            </button>
            {#if ws.profiles.length > 0}
              <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
              <span
                class="collapse-trigger"
                role="button"
                tabindex="0"
                onclick={(e) => { e.stopPropagation(); toggleWs(ws.id); }}
                onkeydown={(e) => e.key === 'Enter' && toggleWs(ws.id)}
              >
                <Icon name={collapsedWs.has(ws.id) ? 'chevron-right' : 'chevron-down'} size={10} />
              </span>
            {/if}
          </div>

          {#if !collapsedWs.has(ws.id)}
            {#each ws.profiles as p (p.id)}
              <button
                class="{filterClass('profile', p.id)} profile-item"
                onclick={() => onfilter({ type: 'profile', id: p.id })}
              >
                <Icon name="user" size={11} />
                <span class="p-name">{p.name}</span>
                <span class="count">{p.noteCount}</span>
              </button>
            {/each}
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  {#if tagGroups.length > 0 || true}
    <div class="filter-section">
      <div class="section-label-row">
        <span class="section-label">{$t('notes_areas_title')}</span>
        <button class="btn-add-area" onclick={() => { showNewArea = !showNewArea; newAreaName = ''; }} title={$t('notes_areas_new')}>
          <Icon name="plus" size={11} />
        </button>
      </div>

      {#if showNewArea}
        <div class="new-area-form">
          <input
            type="color"
            bind:value={newAreaColor}
            class="area-color-pick"
            title={$t('notes_areas_color')}
          />
          <input
            type="text"
            bind:value={newAreaName}
            placeholder={$t('notes_areas_placeholder')}
            class="area-name-input"
            onkeydown={(e) => { if (e.key === 'Enter') createArea(); if (e.key === 'Escape') { showNewArea = false; } }}
          />
          <button class="btn-area-save" onclick={createArea} disabled={!newAreaName.trim() || creating}>
            {creating ? '…' : $t('notes_areas_add')}
          </button>
        </div>
      {/if}

      {#each tagGroups as tag (tag.name)}
        <button
          class={filterClass('tag', tag.name)}
          onclick={() => onfilter({ type: 'tag', id: tag.name })}
        >
          <span class="tag-dot" style="background:{tag.color}"></span>
          <span class="tag-name">{tag.name}</span>
          {#if tag.count > 0}
            <span class="count">{tag.count}</span>
          {/if}
        </button>
      {/each}

      {#if tagGroups.length === 0 && !showNewArea}
        <span class="areas-empty">{$t('notes_areas_empty')}</span>
      {/if}
    </div>
  {/if}
</div>

<style>
  .filters {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.5rem 0;
    overflow-y: auto;
  }

  .filter-section {
    display: flex;
    flex-direction: column;
    padding: 0 0.5rem;
    gap: 0.1rem;
  }

  .section-label {
    font-size: 0.68rem;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-3);
    padding: 0.6rem 0.5rem 0.2rem;
    font-weight: 600;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.35rem 0.5rem;
    border: none;
    background: none;
    cursor: pointer;
    color: var(--text-2);
    font-size: 0.82rem;
    border-radius: var(--radius-sm);
    text-align: left;
    transition: background 0.1s, color 0.1s;
    width: 100%;
  }

  .nav-item:hover { background: var(--surface); color: var(--text); }
  .nav-item.active { background: var(--accent-bg); color: var(--accent); }

  .count {
    margin-left: auto;
    font-size: 0.7rem;
    color: var(--text-3);
    background: var(--surface-2);
    padding: 0.05rem 0.35rem;
    border-radius: 999px;
    flex-shrink: 0;
  }

  .nav-item.active .count {
    background: var(--accent-bg);
    color: var(--accent);
  }

  .ws-node {
    display: flex;
    flex-direction: column;
  }

  .ws-dot, .tag-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .ws-name, .p-name, .tag-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }

  .collapse-trigger {
    cursor: pointer;
    color: var(--text-3);
    padding: 0 0.25rem;
    display: flex;
    align-items: center;
    flex-shrink: 0;
    font-size: 0;
  }

  .ws-item {
    flex: 1;
    min-width: 0;
  }

  .ws-node {
    display: flex;
    flex-direction: column;
  }

  .ws-node-row {
    display: flex;
    align-items: center;
  }

  .profile-item {
    padding-left: 1.5rem;
    font-size: 0.78rem;
  }

  .section-label-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 0.5rem;
    margin-bottom: 0.15rem;
  }
  .btn-add-area {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-2);
    padding: 0.1rem 0.2rem;
    border-radius: 3px;
    display: flex;
    align-items: center;
    line-height: 1;
  }
  .btn-add-area:hover { color: var(--accent); background: var(--bg-3); }

  .new-area-form {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.3rem 0.5rem;
    margin-bottom: 0.2rem;
  }
  .area-color-pick {
    width: 1.4rem;
    height: 1.4rem;
    border: none;
    border-radius: 50%;
    padding: 0;
    cursor: pointer;
    background: none;
    flex-shrink: 0;
  }
  .area-name-input {
    flex: 1;
    background: var(--bg-3);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 0.25rem 0.4rem;
    font-size: 0.78rem;
    color: var(--text-1);
    outline: none;
    min-width: 0;
  }
  .area-name-input:focus { border-color: var(--accent); }
  .btn-area-save {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: 4px;
    padding: 0.25rem 0.5rem;
    font-size: 0.75rem;
    cursor: pointer;
    flex-shrink: 0;
  }
  .btn-area-save:disabled { opacity: 0.5; cursor: default; }
  .areas-empty {
    font-size: 0.75rem;
    color: var(--text-2);
    padding: 0.2rem 0.5rem;
    font-style: italic;
  }
</style>
