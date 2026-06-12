<script lang="ts">
  import { notesStore } from '$lib/store/notes.svelte';
  import { api } from '$lib/api';
  import type { NoteTag, NoteFolder } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import NoteTagsInput from './NoteTagsInput.svelte';
  import { t } from '$lib/i18n';

  interface Props {
    allTags: NoteTag[];
    folders: NoteFolder[];
  }

  let { allTags, folders }: Props = $props();

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

  let titleHovered = $state(false);
  let showDeleteConfirm = $state(false);
  let folderPickerOpen = $state(false);

  const activeFolder = $derived(
    note ? folders.find(f => f.id === note.folder_id) ?? null : null
  );

  async function confirmDelete() {
    if (!note) return;
    await notesStore.deleteNote(note.id);
    showDeleteConfirm = false;
  }

  function onTitleChange() {
    notesStore.onTitleChange(titleValue);
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
      <div class="title-wrap"
        onmouseenter={() => titleHovered = true}
        onmouseleave={() => titleHovered = false}
      >
        <input
          bind:this={titleInputEl}
          bind:value={titleValue}
          type="text"
          class="title-input"
          placeholder={$t('notes_title_placeholder')}
          maxlength="100"
          oninput={onTitleChange}
        />
        {#if titleHovered}
          <span class="title-hint"><Icon name="pencil" size={12} /></span>
        {/if}
      </div>
      <NoteTagsInput
        selectedTags={note.tags}
        {allTags}
        onchange={(tagNames) => notesStore.setTags(note!.id, tagNames)}
      />
      <!-- Folder picker -->
      <div class="folder-picker-wrap">
        <button
          class="folder-badge"
          class:active={!!activeFolder}
          onclick={() => folderPickerOpen = !folderPickerOpen}
          title="Папка"
        >
          <Icon name="folder" size={12} />
          {#if activeFolder}
            <span class="folder-badge-name">{activeFolder.name}</span>
            <span
              class="folder-badge-dot"
              style="background:{activeFolder.color}"
            ></span>
          {/if}
        </button>
        {#if folderPickerOpen}
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
          <div class="folder-dropdown-overlay" onclick={() => folderPickerOpen = false} role="presentation"></div>
          <div class="folder-dropdown">
            <button
              class="folder-option"
              class:selected={!note.folder_id}
              onclick={() => { void notesStore.setNoteFolder(note!.id, null); folderPickerOpen = false; }}
            >
              <Icon name="x" size={11} />
              <span>Без папки</span>
            </button>
            {#each folders as f (f.id)}
              <button
                class="folder-option"
                class:selected={note.folder_id === f.id}
                onclick={() => { void notesStore.setNoteFolder(note!.id, f.id); folderPickerOpen = false; }}
              >
                <span class="folder-opt-dot" style="background:{f.color}"></span>
                <span>{f.name}</span>
              </button>
            {/each}
            {#if folders.length === 0}
              <span class="folder-option-empty">Папок нет</span>
            {/if}
          </div>
        {/if}
      </div>
      <span class="save-status {saveClass[saveStatus] ?? 'status-saved'}">
        {saveLabel[saveStatus] ?? $t('note_status_saved')}
      </span>
    </div>

    <div class="note-content">
      <textarea
        bind:value={contentValue}
        class="editor-body"
        placeholder={$t('note_content_placeholder')}
        oninput={onBodyChange}
        spellcheck="false"
      ></textarea>
    </div>

    <div class="editor-footer">
      <span class="footer-meta">
        {note.format.toUpperCase()}
        {#if note.bindings.length > 0}
          · {note.bindings.some(b => b.startsWith('profile:')) ? 'profile' : 'workspace'}
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
    padding: 0.6rem 1rem;
    flex-shrink: 0;
  }

  .title-wrap {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    width: 180px;
    flex-shrink: 0;
  }

  .title-hint {
    color: var(--accent);
    flex-shrink: 0;
    display: flex;
    align-items: center;
  }

  .title-input {
    background: none;
    border: none;
    outline: none;
    font-size: 1rem;
    font-weight: 600;
    color: var(--text);
    padding: 0;
    min-width: 0;
    flex: 1;
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

  .note-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    margin: 0 0.75rem 0.75rem;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--surface);
  }

  .editor-body {
    flex: 1;
    padding: 0.5rem 1rem;
    background: none;
    border: none;
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

  /* Folder picker */
  .folder-picker-wrap {
    position: relative;
    flex-shrink: 0;
  }

  .folder-badge {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.15rem 0.4rem;
    border: 1px solid var(--border);
    border-radius: 999px;
    background: none;
    cursor: pointer;
    color: var(--text-3);
    font-size: 0.72rem;
    transition: background 0.1s, color 0.1s, border-color 0.1s;
  }

  .folder-badge:hover { background: var(--surface); color: var(--text-2); }
  .folder-badge.active { color: var(--text-2); border-color: var(--border); background: var(--surface); }

  .folder-badge-name {
    max-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .folder-badge-dot {
    width: 7px; height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .folder-dropdown-overlay {
    position: fixed;
    inset: 0;
    z-index: 49;
  }

  .folder-dropdown {
    position: absolute;
    top: calc(100% + 4px);
    right: 0;
    min-width: 160px;
    background: var(--bg-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    box-shadow: var(--shadow-lg);
    z-index: 50;
    display: flex;
    flex-direction: column;
    padding: 0.25rem;
    gap: 0.1rem;
    max-height: 220px;
    overflow-y: auto;
  }

  .folder-option {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.3rem 0.5rem;
    border: none;
    border-radius: var(--radius-sm);
    background: none;
    cursor: pointer;
    font-size: 0.8rem;
    color: var(--text-2);
    text-align: left;
    transition: background 0.1s;
  }
  .folder-option:hover { background: var(--surface); color: var(--text); }
  .folder-option.selected { color: var(--accent); background: var(--accent-bg); }

  .folder-opt-dot {
    width: 8px; height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .folder-option-empty {
    padding: 0.3rem 0.5rem;
    font-size: 0.78rem;
    color: var(--text-3);
    font-style: italic;
  }
</style>
