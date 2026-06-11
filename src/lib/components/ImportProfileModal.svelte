<script lang="ts">
  import { t } from '$lib/i18n';
  import { api } from '$lib/api';
  import type { Profile, ProfileExport } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import { formatError } from '$lib/utils';

  interface Props {
    workspaceId: string;
    open: boolean;
    onclose: () => void;
    onimported: (p: Profile) => void;
  }

  let { workspaceId, open, onclose, onimported }: Props = $props();

  type Tab = 'file' | 'json';
  let activeTab = $state<Tab>('file');
  let pastedJson = $state('');
  let fileInput = $state<HTMLInputElement | null>(null);
  let selectedFile = $state<File | null>(null);
  let preview = $state<ProfileExport | null>(null);
  let previewError = $state('');
  let loading = $state(false);
  let error = $state('');

  function reset() {
    pastedJson = '';
    selectedFile = null;
    preview = null;
    previewError = '';
    error = '';
  }

  $effect(() => {
    if (!open) reset();
  });

  function handleFileChange(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    selectedFile = file;
    preview = null;
    previewError = '';
    error = '';

    if (!file) return;

    if (file.name.endsWith('.json')) {
      const reader = new FileReader();
      reader.onload = () => tryParsePreview(reader.result as string);
      reader.readAsText(file);
    } else if (!file.name.endsWith('.zip')) {
      previewError = $t('import_invalid_type');
      selectedFile = null;
    }
    // ZIP: no preview, just show filename
  }

  function handleJsonInput() {
    preview = null;
    previewError = '';
    if (pastedJson.trim()) tryParsePreview(pastedJson);
  }

  function tryParsePreview(json: string) {
    try {
      const parsed = JSON.parse(json) as ProfileExport;
      if (!parsed.version || !parsed.profile) {
        previewError = 'Not a valid profile export';
        return;
      }
      preview = parsed;
    } catch {
      previewError = 'Invalid JSON';
    }
  }

  async function doImport() {
    loading = true;
    error = '';
    try {
      let imported: Profile;

      if (activeTab === 'json') {
        imported = await api.profiles.importJson(pastedJson, workspaceId);
      } else if (selectedFile) {
        if (selectedFile.name.endsWith('.json')) {
          const text = await selectedFile.text();
          imported = await api.profiles.importJson(text, workspaceId);
        } else {
          const buf = await selectedFile.arrayBuffer();
          const b64 = arrayBufferToBase64(buf);
          imported = await api.profiles.importZipData(b64, workspaceId);
        }
      } else {
        error = $t('import_no_data');
        return;
      }

      onimported(imported);
      onclose();
    } catch (e) {
      error = formatError(e);
    } finally {
      loading = false;
    }
  }

  function arrayBufferToBase64(buf: ArrayBuffer): string {
    const bytes = new Uint8Array(buf);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && open) onclose();
  }

  const canImport = $derived(
    !loading &&
    (activeTab === 'json' ? pastedJson.trim().length > 0 : selectedFile !== null)
  );
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
  <div class="overlay" onclick={onclose} role="presentation" tabindex="-1">
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
    <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">

      <div class="modal-header">
        <span class="modal-title">
          <Icon name="download" size={15} />
          {$t('import_title')}
        </span>
        <button class="close-btn" onclick={onclose}><Icon name="x" size={14} /></button>
      </div>

      <div class="tabs">
        <button
          class="tab-btn"
          class:active={activeTab === 'file'}
          onclick={() => { activeTab = 'file'; reset(); }}
        >
          <Icon name="file" size={13} />
          {$t('import_tab_file')}
        </button>
        <button
          class="tab-btn"
          class:active={activeTab === 'json'}
          onclick={() => { activeTab = 'json'; reset(); }}
        >
          <Icon name="code" size={13} />
          {$t('import_tab_json')}
        </button>
      </div>

      {#if activeTab === 'file'}
        <div class="file-section">
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <div
            class="file-drop"
            class:has-file={selectedFile !== null}
            onclick={() => fileInput?.click()}
            role="button"
            tabindex="0"
            onkeydown={(e) => e.key === 'Enter' && fileInput?.click()}
          >
            {#if selectedFile}
              <Icon name="file-check" size={20} />
              <span class="file-name">{selectedFile.name}</span>
              <span class="file-meta">{(selectedFile.size / 1024).toFixed(1)} KB</span>
            {:else}
              <Icon name="upload" size={20} />
              <span>{$t('import_drop_hint')}</span>
              <span class="file-meta">{$t('import_drop_type')}</span>
            {/if}
          </div>
          <input
            type="file"
            accept=".json,.zip"
            style="display:none"
            bind:this={fileInput}
            onchange={handleFileChange}
          />
        </div>
      {:else}
        <textarea
          class="json-input"
          placeholder={$t('import_json_placeholder')}
          bind:value={pastedJson}
          oninput={handleJsonInput}
          rows="8"
          spellcheck="false"
        ></textarea>
      {/if}

      {#if previewError}
        <div class="error-msg">{previewError}</div>
      {/if}

      {#if preview}
        <div class="preview">
          <div class="preview-title">{$t('import_preview_title')}</div>
          <div class="preview-row">
            <span class="preview-label">Name</span>
            <span class="preview-value">{preview.profile.name}</span>
          </div>
          <div class="preview-row">
            <span class="preview-label">OS</span>
            <span class="preview-value">{preview.profile.fingerprint_preset} / {preview.profile.browser_type}</span>
          </div>
          <div class="preview-row">
            <span class="preview-label">Locale</span>
            <span class="preview-value">{preview.profile.locale}</span>
          </div>
          {#if preview.proxy}
            <div class="preview-row">
              <span class="preview-label">Proxy</span>
              <span class="preview-value proxy-value">
                <Icon name="globe" size={11} />
                {preview.proxy.proxy_type}://{preview.proxy.host}:{preview.proxy.port}
              </span>
            </div>
          {/if}
        </div>
      {/if}

      {#if selectedFile?.name.endsWith('.zip') && !previewError}
        <div class="zip-note">
          <Icon name="info" size={12} />
          {$t('import_zip_note')}
        </div>
      {/if}

      {#if error}
        <div class="error-msg">{error}</div>
      {/if}

      <div class="modal-footer">
        <button class="btn btn-ghost" onclick={onclose}>{$t('profile_btn_cancel')}</button>
        <button class="btn btn-primary" disabled={!canImport} onclick={doImport}>
          {loading ? $t('import_btn_loading') : $t('import_btn')}
        </button>
      </div>

    </div>
  </div>
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 200;
    backdrop-filter: blur(2px);
  }

  .modal {
    background: var(--bg-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1.25rem 1.5rem;
    box-shadow: var(--shadow-lg);
    width: 420px;
    max-height: 90vh;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 0.875rem;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .modal-title {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--text);
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }

  .close-btn {
    background: none;
    border: none;
    color: var(--text-2);
    cursor: pointer;
    padding: 2px;
    display: flex;
    align-items: center;
    border-radius: var(--radius-sm);
  }
  .close-btn:hover { background: var(--surface-2); }

  .tabs {
    display: flex;
    gap: 0.2rem;
    border-bottom: 1px solid var(--border);
    padding: 0.3rem 0.5rem 0;
  }

  .tab-btn {
    display: flex; align-items: center; justify-content: center; gap: 0.35rem;
    padding: 0.35rem 0.85rem; font-size: 0.8rem;
    border: none; background: none; cursor: pointer;
    color: var(--text-2);
    border-radius: var(--radius-sm) var(--radius-sm) 0 0;
    border-bottom: 2px solid transparent;
    margin-bottom: -1px; transition: all 0.15s;
  }
  .tab-btn:hover { background: var(--surface); color: var(--text); }
  .tab-btn.active { color: var(--accent); border-bottom-color: var(--accent); background: var(--accent-bg); font-weight: 500; }

  .file-section {
    display: flex;
    flex-direction: column;
  }

  .file-drop {
    border: 2px dashed var(--border-2);
    border-radius: var(--radius-sm);
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.4rem;
    cursor: pointer;
    color: var(--text-2);
    font-size: 0.85rem;
    transition: border-color 0.15s, background 0.15s;
  }
  .file-drop:hover, .file-drop:focus {
    border-color: var(--accent);
    background: var(--accent-bg);
    outline: none;
  }
  .file-drop.has-file {
    border-color: var(--accent);
    color: var(--text);
  }

  .file-name { font-weight: 500; color: var(--text); }
  .file-meta { font-size: 0.75rem; color: var(--text-3); }

  .json-input {
    width: 100%;
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--text);
    font-size: 0.78rem;
    font-family: monospace;
    padding: 0.6rem 0.75rem;
    resize: vertical;
    box-sizing: border-box;
  }
  .json-input:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-bg);
  }

  .preview {
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.6rem 0.75rem;
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .preview-title {
    font-size: 0.72rem;
    font-weight: 600;
    text-transform: uppercase;
    color: var(--text-3);
    letter-spacing: 0.05em;
    margin-bottom: 0.2rem;
  }

  .preview-row {
    display: flex;
    gap: 0.5rem;
    font-size: 0.82rem;
  }

  .preview-label {
    color: var(--text-3);
    width: 52px;
    flex-shrink: 0;
  }

  .preview-value { color: var(--text); }

  .proxy-value {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    font-family: monospace;
    font-size: 0.78rem;
  }

  .zip-note {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    font-size: 0.78rem;
    color: var(--text-3);
  }

  .modal-footer {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
    padding-top: 0.25rem;
  }
</style>
