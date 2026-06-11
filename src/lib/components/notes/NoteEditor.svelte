<script lang="ts">
  import { notesStore } from '$lib/store/notes.svelte';
  import { api } from '$lib/api';
  import type { NoteTag } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import NoteTagsInput from './NoteTagsInput.svelte';
  import { t } from '$lib/i18n';

  interface Props {
    allTags: NoteTag[];
  }

  let { allTags }: Props = $props();

  const note = $derived(notesStore.activeNote);
  const saveStatus = $derived(notesStore.saveStatus);
  const externalChange = $derived(notesStore.externalChange);

  let titleValue = $state('');
  let contentValue = $state('');
  let titleInputEl: HTMLInputElement | null = $state(null);

  let _lastNoteId: string | null = null;
  $effect(() => {
    if (note) {
      if (note.id !== _lastNoteId) {
        _lastNoteId = note.id;
      }
      titleValue = note.title;
      contentValue = note.content ?? '';
    }
  });

  let showDeleteConfirm = $state(false);

  async function confirmDelete() {
    if (!note) return;
    await notesStore.deleteNote(note.id);
    showDeleteConfirm = false;
  }

  function onBodyChange() {
    notesStore.onContentChange(contentValue);
  }

  const saveLabel = $derived<Record<string, string>>({
    saved: $t('note_status_saved'),
    saving: $t('note_status_saving'),
    unsaved: $t('note_status_unsaved'),
    failed: $t('note_status_error'),
    external: $t('note_status_external'),
  });

  const saveClass: Record<string, string> = {
    saved: 'status-saved',
    saving: 'status-saving',
    unsaved: 'status-unsaved',
    failed: 'status-failed',
    external: 'status-external',
  };
</script>

{#if !note}
  <div class="editor-empty">
    <Icon name="file-text" size={28} />
    <p>{$t('note_empty_hint')}</p>
  </div>
{:else}
  <div class="editor">
    <!-- Recovery banner -->
    {#if note.has_draft}
      <div class="banner banner-warn">
        <span>{$t('note_draft_found')}</span>
        <div class="banner-actions">
          <button onclick={() => notesStore.recoverDraft(note!.id)}>{$t('note_draft_recover')}</button>
          <button onclick={() => notesStore.discardDraft(note!.id)}>{$t('note_draft_discard')}</button>
        </div>
      </div>
    {/if}

    <!-- External change banner -->
    {#if externalChange}
      <div class="banner banner-info">
        <span>{$t('note_external_change')}</span>
        <div class="banner-actions">
          <button onclick={() => notesStore.acceptExternalChange()}>{$t('note_external_accept')}</button>
          <button onclick={() => notesStore.discardExternalChange()}>{$t('note_external_keep')}</button>
        </div>
      </div>
    {/if}

    <div class="editor-header">
      <div class="title-wrap">
        <input
          bind:this={titleInputEl}
          bind:value={titleValue}
          type="text"
          class="title-input"
          placeholder={$t('notes_title_placeholder')}
          oninput={onTitleChange}
        />
        <Icon name="pencil" size={13} class="title-edit-icon" />
      </div>
      <span class="save-status {saveClass[saveStatus] ?? 'status-saved'}">
        {saveLabel[saveStatus] ?? $t('note_status_saved')}
      </span>
    </div>

    <div class="editor-tags">
      <NoteTagsInput
        selectedTags={note.tags}
        {allTags}
        onchange={(tagNames) => notesStore.setTags(note!.id, tagNames)}
      />
    </div>

    <textarea
      bind:value={contentValue}
      class="editor-body"
      placeholder={$t('note_content_placeholder')}
      oninput={onBodyChange}
      spellcheck="false"
    ></textarea>

    <div class="editor-footer">
      <span class="footer-meta">
        {note.format.toUpperCase()}
        {#if note.scope !== 'global'}
          · {note.scope}
        {/if}
      </span>
      <div class="footer-actions">
        <button
          class="icon-action"
          onclick={() => note && notesStore.togglePin(note.id)}
          title={note.pinned ? $t('note_btn_unpin') : $t('note_btn_pin')}
          class:active={note.pinned}
        >
          <Icon name="pin" size={13} />
        </button>
        <button
          class="icon-action"
          onclick={() => note && notesStore.archiveNote(note.id)}
          title={$t('note_btn_archive')}
        >
          <Icon name="archive" size={13} />
        </button>
        <button
          class="icon-action"
          onclick={() => note && api.notes.openExternal(note.id)}
          title={$t('note_btn_open_external')}
        >
          <Icon name="external-link" size={13} />
        </button>
        <button
          class="icon-action icon-danger"
          onclick={() => (showDeleteConfirm = true)}
          title={$t('note_btn_delete')}
        >
          <Icon name="trash-2" size={13} />
        </button>
      </div>
    </div>

    {#if showDeleteConfirm}
      <div class="delete-overlay">
        <div class="delete-modal">
          <p class="delete-title">{$t('note_delete_title')}</p>
          <p class="delete-warn">
            {$t('note_delete_body1')}
            {$t('note_delete_body2')}
          </p>
          <div class="delete-actions">
            <button class="btn-cancel" onclick={() => (showDeleteConfirm = false)}>{$t('notes_btn_cancel')}</button>
            <button class="btn-delete" onclick={confirmDelete}>{$t('note_delete_confirm')}</button>
          </div>
        </div>
      </div>
    {/if}
  </div>
{/if}

<style>
  .editor-empty {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.75rem;
    color: var(--text-2);
    font-size: 0.85rem;
    text-align: center;
    padding: 2rem;
  }

  .editor-empty p { margin: 0; }

  .editor {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    position: relative;
  }

  .banner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
    padding: 0.5rem 0.75rem;
    font-size: 0.78rem;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .banner-warn { background: var(--warn-bg); color: var(--warn-text); }
  .banner-info { background: var(--accent-bg); color: var(--accent); }

  .banner-actions {
    display: flex;
    gap: 0.4rem;
    flex-shrink: 0;
  }

  .banner-actions button {
    background: none;
    border: 1px solid currentColor;
    border-radius: var(--radius-sm);
    padding: 0.15rem 0.5rem;
    font-size: 0.75rem;
    color: inherit;
    cursor: pointer;
    transition: background 0.15s;
  }

  .banner-actions button:hover { background: rgba(255,255,255,0.1); }

  .editor-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1rem 0.4rem;
    flex-shrink: 0;
  }

  .title-wrap {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 0.4rem;
    min-width: 0;
  }

  .title-wrap :global(.title-edit-icon) {
    color: var(--text-3, var(--text-2));
    opacity: 0.5;
    flex-shrink: 0;
    transition: opacity 0.15s;
  }
  .title-wrap:focus-within :global(.title-edit-icon) {
    opacity: 1;
    color: var(--accent);
  }

  .title-input {
    flex: 1;
    background: none;
    border: none;
    outline: none;
    font-size: 1rem;
    font-weight: 600;
    color: var(--text);
    padding: 0;
    min-width: 0;
  }

  .title-input::placeholder { color: var(--text-3); }

  .save-status {
    font-size: 0.72rem;
    flex-shrink: 0;
    padding: 0.1rem 0.4rem;
    border-radius: 999px;
    font-weight: 500;
  }

  .status-saved  { color: var(--success-text); background: var(--success-bg); }
  .status-saving { color: var(--accent); background: var(--accent-bg); }
  .status-unsaved { color: var(--warn-text); background: var(--warn-bg); }
  .status-failed { color: var(--danger-text); background: var(--danger-bg); }
  .status-external { color: var(--warn-text); background: var(--warn-bg); }

  .editor-tags {
    padding: 0 1rem 0.5rem;
    flex-shrink: 0;
  }

  .toolbar {
    display: flex;
    align-items: center;
    gap: 0.1rem;
    padding: 0.3rem 0.75rem;
    border-top: 1px solid var(--border);
    border-bottom: 1px solid var(--border);
    background: var(--bg-1);
    flex-shrink: 0;
    flex-wrap: wrap;
  }
  .tb-btn {
    background: none;
    border: none;
    border-radius: 4px;
    padding: 0.2rem 0.45rem;
    cursor: pointer;
    color: var(--text-2);
    font-size: 0.8rem;
    line-height: 1;
    transition: background 0.12s, color 0.12s;
    min-width: 1.8rem;
    text-align: center;
  }
  .tb-btn:hover { background: var(--bg-3); color: var(--text-1); }
  .tb-btn b, .tb-btn i, .tb-btn u, .tb-btn s { font-size: 0.82rem; }
  .tb-btn code { font-size: 0.75rem; font-family: monospace; }
  .tb-sep {
    width: 1px;
    height: 1.1rem;
    background: var(--border);
    margin: 0 0.2rem;
    flex-shrink: 0;
  }
  .tb-spacer { flex: 1; }
  .tb-mode-toggle {
    font-size: 0.72rem;
    padding: 0.2rem 0.6rem;
    border: 1px solid var(--border);
    border-radius: 4px;
    color: var(--text-2);
  }
  .tb-mode-toggle.active {
    border-color: var(--accent);
    color: var(--accent);
  }
  .tb-mode-toggle:hover { background: var(--bg-3); color: var(--text-1); }

  .editor-body {
    flex: 1;
    padding: 0.5rem 1rem;
    background: none;
    border: none;
    border-top: 1px solid var(--border);
    outline: none;
    resize: none;
    font-size: 0.88rem;
    line-height: 1.6;
    color: var(--text);
    font-family: 'Menlo', 'Consolas', 'SF Mono', monospace;
    overflow-y: auto;
  }

  .editor-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.4rem 0.75rem;
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .footer-meta {
    font-size: 0.72rem;
    color: var(--text-3);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    font-family: monospace;
  }

  .footer-actions {
    display: flex;
    gap: 0.1rem;
  }

  .icon-action {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-2);
    padding: 0.25rem;
    border-radius: var(--radius-sm);
    display: flex;
    align-items: center;
    transition: color 0.15s, background 0.15s;
  }

  .icon-action:hover { color: var(--text); background: var(--surface); }
  .icon-action.active { color: var(--accent); }
  .icon-danger:hover { color: #ef4444 !important; }

  .delete-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0,0,0,0.55);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
    border-radius: inherit;
  }
  .delete-modal {
    background: var(--bg-2);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem 1.5rem;
    max-width: 320px;
    width: 90%;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }
  .delete-title {
    margin: 0;
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--text-1);
  }
  .delete-warn {
    margin: 0;
    font-size: 0.82rem;
    color: var(--text-2);
    line-height: 1.5;
  }
  .delete-warn strong { color: #ef4444; }
  .delete-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
    margin-top: 0.25rem;
  }
  .btn-cancel {
    background: none;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.35rem 0.9rem;
    font-size: 0.82rem;
    color: var(--text-2);
    cursor: pointer;
  }
  .btn-cancel:hover { background: var(--bg-3); }
  .btn-delete {
    background: #ef4444;
    border: none;
    border-radius: var(--radius-sm);
    padding: 0.35rem 0.9rem;
    font-size: 0.82rem;
    color: #fff;
    cursor: pointer;
    font-weight: 500;
  }
  .btn-delete:hover { background: #dc2626; }
</style>
