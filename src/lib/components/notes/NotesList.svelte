<script lang="ts">
  import type { NoteListItem } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import { t } from '$lib/i18n';

  interface Props {
    notes: NoteListItem[];
    activeId: string | null;
    onselect: (id: string) => void;
    oncreate: () => void;
    workspaceName?: (id: string) => string;
    profileName?: (id: string) => string;
  }

  let { notes, activeId, onselect, oncreate, workspaceName, profileName }: Props = $props();

  function scopeLabel(n: NoteListItem): string {
    const profileTag = n.bindings.find(b => b.startsWith('profile:'));
    if (profileTag && profileName) return profileName(profileTag.slice('profile:'.length));
    const wsTag = n.bindings.find(b => b.startsWith('workspace:'));
    if (wsTag && workspaceName) return workspaceName(wsTag.slice('workspace:'.length));
    return $t('notes_scope_global');
  }

  function scopeColor(n: NoteListItem): string {
    if (n.bindings.some(b => b.startsWith('profile:'))) return 'var(--accent)';
    if (n.bindings.some(b => b.startsWith('workspace:'))) return 'var(--success)';
    return 'var(--text-2)';
  }

  function relativeTime(iso: string): string {
    const diff = Date.now() - new Date(iso).getTime();
    const m = Math.floor(diff / 60000);
    if (m < 1) return $t('notes_time_just_now');
    if (m < 60) return $t('notes_time_m_ago', { m: String(m) });
    const h = Math.floor(m / 60);
    if (h < 24) return $t('notes_time_h_ago', { h: String(h) });
    return $t('notes_time_d_ago', { d: String(Math.floor(h / 24)) });
  }
</script>

<div class="notes-list">
  {#if notes.length === 0}
    <div class="empty-state">
      <p>{$t('notes_list_empty')}</p>
      <button class="btn-create" onclick={oncreate}>
        <Icon name="plus" size={13} /> {$t('notes_list_new')}
      </button>
    </div>
  {:else}
    {#each notes as note (note.id)}
      <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
      <div
        class="note-card"
        class:active={note.id === activeId}
        onclick={() => onselect(note.id)}
        role="button"
        tabindex="0"
        onkeydown={(e) => e.key === 'Enter' && onselect(note.id)}
      >
        <div class="card-top">
          <span class="note-title">
            {#if note.pinned}
              <Icon name="pin" size={11} />
            {/if}
            {note.title || $t('notes_untitled')}
          </span>
          <span class="note-meta">
            {#if note.has_draft}
              <span class="draft-dot" title={$t('notes_unsaved_draft')}></span>
            {/if}
            <span class="note-format">{note.format}</span>
          </span>
        </div>

        <div class="card-mid">
          <span class="scope-badge" style="color: {scopeColor(note)}">
            {scopeLabel(note)}
          </span>
          <span class="note-time">{relativeTime(note.updated_at)}</span>
        </div>

        {#if note.preview}
          <p class="note-preview">{note.preview}</p>
        {/if}

        {#if note.tags.length > 0}
          <div class="card-tags">
            {#each note.tags.slice(0, 4) as tag (tag.id)}
              <span class="tag-chip" style="border-color:{tag.color}; color:{tag.color}; background:{tag.color}18">
                {tag.name}
              </span>
            {/each}
            {#if note.tags.length > 4}
              <span class="tag-more">+{note.tags.length - 4}</span>
            {/if}
          </div>
        {/if}
      </div>
    {/each}
  {/if}
</div>

<style>
  .notes-list {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.75rem;
    padding: 2.5rem 1rem;
    color: var(--text-2);
    font-size: 0.85rem;
    text-align: center;
  }

  .empty-state p { margin: 0; }

  .btn-create {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: var(--radius-sm);
    padding: 0.4rem 0.9rem;
    font-size: 0.8rem;
    cursor: pointer;
    transition: background 0.15s;
  }

  .btn-create:hover { background: var(--accent-hover); }

  .note-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.55rem 0.75rem;
    cursor: pointer;
    transition: border-color 0.15s, background 0.15s;
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .note-card:hover { border-color: var(--border-2); }
  .note-card.active { border-color: var(--accent); background: var(--accent-bg); }

  .card-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.4rem;
  }

  .note-title {
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: flex;
    align-items: center;
    gap: 0.3rem;
    flex: 1;
    min-width: 0;
  }

  .note-meta {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    flex-shrink: 0;
  }

  .note-format {
    font-size: 0.68rem;
    color: var(--text-3);
    text-transform: uppercase;
    font-family: monospace;
    background: var(--surface-2);
    padding: 0.05rem 0.3rem;
    border-radius: 3px;
  }

  .draft-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--warn-text);
    flex-shrink: 0;
  }

  .card-mid {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.4rem;
  }

  .scope-badge {
    font-size: 0.72rem;
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 140px;
  }

  .note-time {
    font-size: 0.72rem;
    color: var(--text-3);
    flex-shrink: 0;
  }

  .note-preview {
    margin: 0;
    font-size: 0.73rem;
    color: var(--text-2);
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    line-height: 1.4;
  }

  .card-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
  }

  .tag-chip {
    font-size: 0.68rem;
    padding: 0.1rem 0.4rem;
    border-radius: 999px;
    border: 1px solid;
    font-weight: 500;
    white-space: nowrap;
  }

  .tag-more {
    font-size: 0.68rem;
    color: var(--text-2);
    padding: 0.1rem 0.2rem;
  }
</style>
