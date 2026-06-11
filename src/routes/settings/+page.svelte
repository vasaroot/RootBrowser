<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { locale, t } from '$lib/i18n';
  import { theme, toggleTheme } from '$lib/theme';
  import Icon from '$lib/Icon.svelte';
  import { api } from '$lib/api';
  import type { Locale } from '$lib/i18n';
  import type { CamoufoxStatus } from '$lib/types';
  import { formatError } from '$lib/utils';

  const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

  const languages: { value: Locale; label: string; native: string }[] = [
    { value: 'en', label: 'English', native: 'English' },
    { value: 'ru', label: 'Russian', native: 'Русский' },
  ];

  let camoufox = $state<CamoufoxStatus | null>(null);
  let downloading = $state(false);
  let extracting = $state(false);
  let downloadError = $state('');
  let downloadDone = $state('');
  let progress = $state<{ percent: number; downloaded: number; total: number } | null>(null);
  let unlisteners: (() => void)[] = [];

  let appVersion = $state('');
  let latestCamoufox = $state<string | null>(null);
  let checkingUpdate = $state(false);
  let checkUpdateError = $state('');

  // Notes dir
  let notesDir = $state('');
  let notesDirIsCustom = $state(false);
  let notesDirSaving = $state(false);
  let notesDirError = $state('');

  onMount(async () => {
    camoufox = await api.camoufox.status().catch(() => null);

    if (isTauri) {
      const { getVersion } = await import('@tauri-apps/api/app');
      appVersion = await getVersion().catch(() => '');
    }

    // Load notes dir
    try {
      const info = await api.notes.getDir();
      notesDir = info.current;
      notesDirIsCustom = info.is_custom;
    } catch {}

    // Restore state if download was already running
    const dlState = await api.camoufox.downloadState().catch(() => null);
    if (dlState?.state === 'downloading') {
      downloading = true;
      if (dlState.downloaded && dlState.total) {
        progress = { percent: dlState.percent ?? 0, downloaded: dlState.downloaded, total: dlState.total };
      }
    }

    if (isTauri) {
      const { listen } = await import('@tauri-apps/api/event');

      unlisteners.push(await listen<{ state: string; downloaded: number; total: number; percent: number }>(
        'camoufox://progress',
        (e) => {
          downloading = true;
          extracting = false;
          progress = { percent: e.payload.percent, downloaded: e.payload.downloaded, total: e.payload.total };
        }
      ));

      unlisteners.push(await listen('camoufox://extracting', () => {
        extracting = true;
        progress = null;
      }));

      unlisteners.push(await listen<string>('camoufox://done', async (e) => {
        downloading = false;
        extracting = false;
        progress = null;
        downloadDone = e.payload;
        camoufox = await api.camoufox.status().catch(() => null);
        latestCamoufox = null;
      }));

      unlisteners.push(await listen<string>('camoufox://error', (e) => {
        downloading = false;
        extracting = false;
        progress = null;
        if (!e.payload.includes('cancelled')) {
          downloadError = e.payload;
        }
      }));
    }
  });

  onDestroy(() => unlisteners.forEach(fn => fn()));

  function formatMb(bytes: number) {
    return (bytes / 1024 / 1024).toFixed(0) + ' MB';
  }

  async function downloadCamoufox() {
    downloadError = '';
    downloadDone = '';
    try {
      await api.camoufox.download();
      downloading = true;
    } catch (e) {
      downloadError = formatError(e);
    }
  }

  async function cancelDownload() {
    await api.camoufox.cancel().catch(() => {});
    downloading = false;
    extracting = false;
    progress = null;
  }

  async function checkForUpdates() {
    checkingUpdate = true;
    checkUpdateError = '';
    latestCamoufox = null;
    try {
      latestCamoufox = await api.camoufox.latestVersion();
    } catch (e) {
      checkUpdateError = formatError(e);
    } finally {
      checkingUpdate = false;
    }
  }

  function isUpToDate(): boolean {
    if (!latestCamoufox || !camoufox?.camoufox_tag) return false;
    return latestCamoufox === camoufox.camoufox_tag;
  }

  async function browseNotesDir() {
    if (!isTauri) return;
    try {
      const { open } = await import('@tauri-apps/plugin-dialog');
      const selected = await open({ directory: true, multiple: false, title: 'Select notes folder' });
      if (selected && typeof selected === 'string') {
        notesDir = selected;
      }
    } catch {}
  }

  async function saveNotesDir() {
    notesDirSaving = true;
    notesDirError = '';
    try {
      const info = await api.notes.setDir(notesDir.trim() || null);
      notesDir = info.current;
      notesDirIsCustom = info.is_custom;
    } catch (e) {
      notesDirError = formatError(e);
    } finally {
      notesDirSaving = false;
    }
  }

  async function resetNotesDir() {
    notesDirSaving = true;
    notesDirError = '';
    try {
      const info = await api.notes.setDir(null);
      notesDir = info.current;
      notesDirIsCustom = info.is_custom;
    } catch (e) {
      notesDirError = formatError(e);
    } finally {
      notesDirSaving = false;
    }
  }
</script>

<div class="page">
  <h1>{$t('settings_title')}</h1>

  <!-- Camoufox -->
  <div class="card">
    <div class="card-title">Camoufox</div>

    {#if camoufox === null}
      <p class="muted">{$t('settings_camoufox_checking')}</p>
    {:else if camoufox.installed}
      <div class="status-row">
        <span class="badge badge-ok">{$t('settings_camoufox_installed')}</span>
      </div>

      <div class="version-table">
        {#if camoufox.camoufox_tag}
          <div class="version-row">
            <span class="version-label">{$t('settings_camoufox_tag')}</span>
            <span class="version-value">{camoufox.camoufox_tag}</span>
          </div>
        {/if}
        {#if camoufox.version}
          <div class="version-row">
            <span class="version-label">{$t('settings_camoufox_firefox_version')}</span>
            <span class="version-value">{camoufox.version}</span>
          </div>
        {/if}
        {#if camoufox.path}
          <div class="version-row">
            <span class="version-label">Path</span>
            <span class="version-value path-value">{camoufox.path}</span>
          </div>
        {/if}
      </div>

      <div class="btn-row">
        <button class="btn btn-ghost btn-sm" disabled={downloading} onclick={downloadCamoufox}>
          {downloading ? $t('settings_camoufox_btn_updating') : $t('settings_camoufox_btn_update')}
        </button>
        <button class="btn btn-ghost btn-sm" disabled={checkingUpdate || downloading} onclick={checkForUpdates}>
          {checkingUpdate ? $t('settings_camoufox_checking_update') : $t('settings_camoufox_check_update')}
        </button>
        {#if downloading}
          <button class="btn btn-ghost btn-sm" onclick={cancelDownload}>Cancel</button>
        {/if}
      </div>

      {#if latestCamoufox}
        {#if isUpToDate()}
          <p class="ok-msg">{$t('settings_camoufox_up_to_date')}</p>
        {:else}
          <p class="warn-msg">{$t('settings_camoufox_update_available', { version: latestCamoufox })}</p>
        {/if}
      {/if}
      {#if checkUpdateError}
        <div class="error-msg">{checkUpdateError}</div>
      {/if}
    {:else}
      <div class="status-row">
        <span class="badge badge-warn">{$t('settings_camoufox_not_installed')}</span>
      </div>
      <p class="muted small">{$t('settings_camoufox_download_hint')}</p>
      <div class="btn-row">
        <button class="btn btn-primary btn-sm" disabled={downloading} onclick={downloadCamoufox}>
          {downloading ? $t('settings_camoufox_btn_downloading') : $t('settings_camoufox_btn_download')}
        </button>
        {#if downloading}
          <button class="btn btn-ghost btn-sm" onclick={cancelDownload}>Cancel</button>
        {/if}
      </div>
    {/if}

    {#if extracting}
      <p class="muted small">Extracting… please wait</p>
    {/if}

    {#if downloading && progress}
      <div class="progress-wrap">
        <div class="progress-bar">
          <div class="progress-fill" style="width: {progress.percent}%"></div>
        </div>
        <span class="progress-label">
          {formatMb(progress.downloaded)} / {formatMb(progress.total)} · {progress.percent}%
        </span>
      </div>
    {/if}

    {#if downloadDone}
      <p class="ok-msg">{$t('settings_camoufox_success', { version: downloadDone })}</p>
    {/if}
    {#if downloadError}
      <div class="error-msg">{downloadError}</div>
    {/if}
  </div>

  <!-- Language -->
  <div class="card">
    <div class="card-title">{$t('settings_section_language')}</div>
    <p class="muted">{$t('settings_language_label')}</p>
    <div class="lang-options">
      {#each languages as lang}
        <button
          class="lang-btn"
          class:active={$locale === lang.value}
          onclick={() => locale.set(lang.value)}
        >
          <span class="lang-flag">{lang.value === 'en' ? '🇬🇧' : '🇷🇺'}</span>
          <span class="lang-native">{lang.native}</span>
          {#if $locale === lang.value}<span class="lang-check">✓</span>{/if}
        </button>
      {/each}
    </div>
  </div>

  <!-- Theme -->
  <div class="card">
    <div class="card-title">Theme</div>
    <div class="theme-options">
      <button class="theme-opt" class:active={$theme === 'dark'} onclick={() => theme.set('dark')}>
        <span class="theme-icon"><Icon name="moon" size={15} /></span>
        <span>Dark</span>
        {#if $theme === 'dark'}<span class="lang-check">✓</span>{/if}
      </button>
      <button class="theme-opt" class:active={$theme === 'light'} onclick={() => theme.set('light')}>
        <span class="theme-icon"><Icon name="sun" size={15} /></span>
        <span>Light</span>
        {#if $theme === 'light'}<span class="lang-check">✓</span>{/if}
      </button>
    </div>
  </div>

  <!-- Notes -->
  <div class="card">
    <div class="card-title">{$t('settings_notes_section')}</div>
    <p class="muted">{$t('settings_notes_folder_hint')}</p>
    <div class="dir-row">
      <input
        class="dir-input"
        type="text"
        bind:value={notesDir}
        placeholder={$t('settings_notes_folder_placeholder')}
        readonly={!isTauri}
      />
      {#if isTauri}
        <button class="btn btn-ghost btn-sm btn-icon" onclick={browseNotesDir} title={$t('settings_notes_browse')}>
          <Icon name="folder-open" size={14} />
        </button>
      {/if}
    </div>
    <div class="btn-row">
      <button class="btn btn-primary btn-sm" disabled={notesDirSaving} onclick={saveNotesDir}>
        {notesDirSaving ? $t('settings_notes_saving') : $t('settings_notes_save')}
      </button>
      {#if notesDirIsCustom}
        <button class="btn btn-ghost btn-sm" disabled={notesDirSaving} onclick={resetNotesDir}>
          {$t('settings_notes_reset')}
        </button>
      {/if}
    </div>
    {#if notesDirIsCustom}
      <p class="muted small">{$t('settings_notes_custom_active')}</p>
    {/if}
    {#if notesDirError}
      <div class="error-msg">{notesDirError}</div>
    {/if}
  </div>

  <!-- About -->
  <div class="card">
    <div class="card-title">{$t('settings_section_about')}</div>
    <div class="version-table">
      <div class="version-row">
        <span class="version-label">{$t('settings_about_app')}</span>
        <span class="version-value">{appVersion ? `v${appVersion}` : '—'}</span>
      </div>
    </div>
  </div>
</div>

<style>
  .page { max-width: 520px; display: flex; flex-direction: column; gap: 1rem; }

  h1 { font-size: 1.4rem; font-weight: 700; letter-spacing: -0.02em; margin-bottom: 0.25rem; }

  .card {
    background: var(--bg-2); border: 1px solid var(--border);
    border-radius: var(--radius); padding: 1.125rem;
    display: flex; flex-direction: column; gap: 0.75rem;
    box-shadow: var(--shadow);
  }

  .card-title {
    font-size: 0.72rem; font-weight: 700; color: var(--text-3);
    text-transform: uppercase; letter-spacing: 0.08em;
  }

  .status-row { display: flex; align-items: center; gap: 0.75rem; }

  .badge {
    font-size: 0.72rem; font-weight: 600;
    padding: 0.2rem 0.6rem; border-radius: 999px;
  }
  .badge-ok { background: var(--success-bg); color: var(--success-text); border: 1px solid color-mix(in srgb, var(--success) 30%, transparent); }
  .badge-warn { background: var(--warn-bg); color: var(--warn-text); border: 1px solid color-mix(in srgb, var(--warn-text) 30%, transparent); }

  .muted { color: var(--text-2); font-size: 0.85rem; }
  .small { font-size: 0.78rem; }
  .ok-msg { font-size: 0.82rem; color: var(--success-text); }
  .warn-msg { font-size: 0.82rem; color: var(--warn-text); }

  .version-table { display: flex; flex-direction: column; gap: 0.35rem; }
  .version-row { display: flex; align-items: baseline; gap: 0.5rem; }
  .version-label { font-size: 0.75rem; color: var(--text-3); min-width: 80px; flex-shrink: 0; }
  .version-value { font-size: 0.8rem; color: var(--text-2); font-family: monospace; }
  .path-value { font-size: 0.72rem; word-break: break-all; }

  .btn-sm { padding: 0.35rem 0.75rem; font-size: 0.82rem; }
  .btn-row { display: flex; gap: 0.5rem; align-items: center; }

  .progress-wrap { display: flex; flex-direction: column; gap: 0.3rem; }
  .progress-bar { height: 5px; background: var(--surface-2); border-radius: 999px; overflow: hidden; }
  .progress-fill { height: 100%; background: var(--accent); border-radius: 999px; transition: width 0.2s ease; }
  .progress-label { font-size: 0.72rem; color: var(--text-2); font-family: monospace; }

  .lang-options { display: flex; gap: 0.625rem; }

  .lang-btn {
    display: flex; align-items: center; gap: 0.4rem;
    padding: 0.5rem 1rem; background: var(--surface-2);
    border: 1px solid var(--border); border-radius: var(--radius-sm);
    color: var(--text-2); font-size: 0.875rem; cursor: pointer;
    transition: all 0.15s; min-width: 120px;
  }
  .lang-btn:hover { border-color: var(--border-2); color: var(--text); }
  .lang-btn.active { border-color: var(--accent); background: var(--accent-bg); color: var(--text); }

  .lang-flag { font-size: 1.05rem; }
  .lang-native { flex: 1; }
  .lang-check { color: var(--accent); font-weight: 700; }

  .theme-options { display: flex; gap: 0.625rem; }

  .theme-opt {
    display: flex; align-items: center; gap: 0.4rem;
    padding: 0.5rem 1rem; background: var(--surface-2);
    border: 1px solid var(--border); border-radius: var(--radius-sm);
    color: var(--text-2); font-size: 0.875rem; cursor: pointer;
    transition: all 0.15s; min-width: 100px;
  }
  .theme-opt:hover { border-color: var(--border-2); color: var(--text); }
  .theme-opt.active { border-color: var(--accent); background: var(--accent-bg); color: var(--text); }
  .theme-icon { font-size: 1rem; }

  .dir-row {
    display: flex; align-items: center; gap: 0.4rem;
  }
  .dir-input {
    flex: 1; background: var(--bg-1); border: 1px solid var(--border);
    border-radius: var(--radius-sm); padding: 0.4rem 0.6rem;
    font-size: 0.8rem; color: var(--text); font-family: monospace;
    outline: none;
  }
  .dir-input:focus { border-color: var(--accent); }
  .btn-icon { padding: 0.35rem 0.5rem; }
  .error-msg { font-size: 0.8rem; color: var(--error, #ef4444); }
</style>
