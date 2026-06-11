<script lang="ts">
  import { t } from '$lib/i18n';
  import { api } from '$lib/api';
  import type { ExportOptions, Profile, Proxy } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import { formatError } from '$lib/utils';

  interface Props {
    profile: Profile;
    proxy: Proxy | null;
    open: boolean;
    onclose: () => void;
  }

  let { profile, proxy, open, onclose }: Props = $props();

  let includeProxy = $state(false);
  let includeProxyPassword = $state(false);
  let includeFiles = $state(false);
  let loading = $state<'json' | 'zip' | 'preview' | null>(null);
  let error = $state('');
  let successMsg = $state('');
  let previewJson = $state<string | null>(null);
  let copied = $state(false);

  $effect(() => {
    if (open) {
      includeProxy = !!proxy;
      includeProxyPassword = false;
      includeFiles = false;
      error = '';
      successMsg = '';
      previewJson = null;
      copied = false;
    }
  });

  function getOptions(): ExportOptions {
    return {
      include_proxy: includeProxy,
      include_proxy_password: includeProxy && includeProxyPassword,
      include_files: includeFiles,
    };
  }

  async function togglePreview() {
    if (previewJson !== null) { previewJson = null; return; }
    loading = 'preview';
    error = '';
    try {
      previewJson = await api.profiles.exportJson(profile.id, getOptions());
    } catch (e) {
      error = formatError(e);
    } finally {
      loading = null;
    }
  }

  async function copyJson() {
    if (!previewJson) return;
    await navigator.clipboard.writeText(previewJson);
    copied = true;
    setTimeout(() => (copied = false), 2000);
  }

  async function saveJson() {
    loading = 'json';
    error = '';
    successMsg = '';
    try {
      const { save } = await import('@tauri-apps/plugin-dialog');
      const path = await save({
        defaultPath: `${profile.name.replace(/[^a-z0-9_-]/gi, '_')}.json`,
        filters: [{ name: 'JSON', extensions: ['json'] }],
      });
      if (!path) { loading = null; return; }

      await api.profiles.exportJsonToFile(profile.id, getOptions(), path);
      successMsg = `JSON saved: ${path}`;
    } catch (e) {
      error = formatError(e);
    } finally {
      loading = null;
    }
  }

  async function saveZip() {
    loading = 'zip';
    error = '';
    successMsg = '';
    try {
      const { save } = await import('@tauri-apps/plugin-dialog');
      const path = await save({
        defaultPath: `${profile.name.replace(/[^a-z0-9_-]/gi, '_')}.zip`,
        filters: [{ name: 'ZIP archive', extensions: ['zip'] }],
      });
      if (!path) { loading = null; return; }

      await api.profiles.exportZip(profile.id, getOptions(), path);
      successMsg = `ZIP saved: ${path}`;
    } catch (e) {
      error = formatError(e);
    } finally {
      loading = null;
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape' && open) onclose();
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
  <div class="overlay" onclick={onclose} role="presentation" tabindex="-1">
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
    <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" tabindex="-1">

      <div class="modal-header">
        <span class="modal-title">
          <Icon name="upload" size={15} />
          {$t('export_title')}
        </span>
        <button class="close-btn" onclick={onclose}><Icon name="x" size={14} /></button>
      </div>

      <div class="profile-name">{profile.name}</div>

      <div class="options">
        <label class="option-row">
          <input type="checkbox" bind:checked={includeProxy} disabled={!proxy} />
          <span class:muted={!proxy}>
            {$t('export_include_proxy')}
            {#if proxy}
              <span class="hint">({proxy.name})</span>
            {:else}
              <span class="hint">{$t('export_no_proxy')}</span>
            {/if}
          </span>
        </label>

        {#if includeProxy && proxy}
          <label class="option-row indent">
            <input type="checkbox" bind:checked={includeProxyPassword} />
            <span>{$t('export_include_password')}</span>
            <span class="badge-sensitive">{$t('export_sensitive')}</span>
          </label>
        {/if}

        <label class="option-row">
          <input type="checkbox" bind:checked={includeFiles} />
          <span>
            {$t('export_include_files')}
            <span class="hint">{$t('export_include_files_hint')}</span>
          </span>
        </label>

        {#if includeFiles}
          <p class="note">{$t('export_files_note')}</p>
        {/if}
      </div>

      {#if previewJson !== null}
        <div class="json-preview">
          <div class="json-preview-header">
            <span class="json-preview-label">JSON</span>
            <button class="copy-btn" onclick={copyJson}>
              <Icon name={copied ? 'check' : 'copy'} size={12} />
              {copied ? $t('export_btn_copied') : $t('export_btn_copy')}
            </button>
          </div>
          <textarea class="json-area" readonly value={previewJson} spellcheck="false"></textarea>
        </div>
      {/if}

      {#if error}
        <div class="error-msg">{error}</div>
      {/if}
      {#if successMsg}
        <div class="success-msg">{successMsg}</div>
      {/if}

      <div class="modal-footer">
        <button class="btn btn-ghost btn-sm" onclick={onclose}>{$t('profile_btn_cancel')}</button>
        <div class="footer-right">
          <button class="btn btn-ghost btn-sm" disabled={loading !== null} onclick={togglePreview}>
            <Icon name={loading === 'preview' ? 'loader' : previewJson !== null ? 'eye-off' : 'eye'} size={13} />
            {previewJson !== null ? 'JSON' : $t('export_btn_preview')}
          </button>
          <button class="btn btn-ghost btn-sm" disabled={loading !== null} onclick={saveJson}>
            <Icon name={loading === 'json' ? 'loader' : 'file-json'} size={13} />
            JSON
          </button>
          <button class="btn btn-primary btn-sm" disabled={loading !== null} onclick={saveZip}>
            <Icon name={loading === 'zip' ? 'loader' : 'archive'} size={13} />
            ZIP
          </button>
        </div>
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
    width: 480px;
    max-height: 90vh;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 1rem;
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

  .profile-name {
    font-size: 0.8rem;
    color: var(--text-2);
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 0.35rem 0.6rem;
  }

  .options {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .option-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.85rem;
    color: var(--text);
    cursor: pointer;
  }

  .option-row.indent { padding-left: 1.4rem; }

  .option-row input[type="checkbox"] {
    flex-shrink: 0;
    width: auto;
  }

  .hint { font-size: 0.78rem; color: var(--text-3); }
  .muted { color: var(--text-3); }

  .badge-sensitive {
    font-size: 0.68rem;
    background: var(--danger-bg);
    color: var(--danger-text);
    border: 1px solid color-mix(in srgb, var(--danger) 30%, transparent);
    border-radius: 3px;
    padding: 1px 5px;
  }

  .note {
    font-size: 0.75rem;
    color: var(--text-3);
    margin: 0;
    padding-left: 1.4rem;
  }

  /* JSON preview */
  .json-preview {
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    overflow: hidden;
  }

  .json-preview-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.35rem 0.6rem;
    background: var(--surface-2);
    border-bottom: 1px solid var(--border);
  }

  .json-preview-label {
    font-size: 0.72rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-3);
  }

  .copy-btn {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    background: none;
    border: none;
    font-size: 0.75rem;
    color: var(--accent);
    cursor: pointer;
    padding: 0.15rem 0.4rem;
    border-radius: 4px;
  }
  .copy-btn:hover { background: var(--accent-bg); }

  .json-area {
    width: 100%;
    height: 180px;
    background: var(--bg);
    border: none;
    color: var(--text);
    font-size: 0.72rem;
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    padding: 0.6rem 0.75rem;
    resize: none;
    box-sizing: border-box;
    display: block;
    outline: none;
    line-height: 1.6;
  }

  .success-msg {
    font-size: 0.8rem;
    color: var(--success-text);
    background: var(--success-bg);
    border: 1px solid color-mix(in srgb, var(--success) 25%, transparent);
    border-radius: var(--radius-sm);
    padding: 0.4rem 0.6rem;
    word-break: break-all;
  }

  .modal-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: 0.25rem;
  }

  .footer-right {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }


</style>
