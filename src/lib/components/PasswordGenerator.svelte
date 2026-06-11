<script lang="ts">
  import Icon from '$lib/Icon.svelte';
  import { t } from '$lib/i18n';
  import { theme, toggleTheme } from '$lib/theme';
  import { api } from '$lib/api';
  import { pwSettings, generatePassword, type PwEntry } from '$lib/password-gen';
  import CustomSelect from '$lib/components/CustomSelect.svelte';

  let { open = $bindable(false) }: { open: boolean } = $props();

  let currentPassword = $state('');
  let showPassword = $state(false);
  let settingsOpen = $state(false);
  let errorMsg = $state('');
  let toast = $state('');
  let toastTimer: ReturnType<typeof setTimeout>;
  let history = $state<PwEntry[]>([]);
  let revealedIds = $state<Set<string>>(new Set());

  $effect(() => {
    if (open && $pwSettings.historyEnabled) {
      loadHistory();
    }
  });

  function onKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') open = false;
  }

  async function loadHistory() {
    try {
      history = await api.pwgen.list();
    } catch {}
  }

  function generate() {
    errorMsg = '';
    try {
      currentPassword = generatePassword($pwSettings);
      showPassword = true;
      if ($pwSettings.historyEnabled) {
        saveToHistory(currentPassword);
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      errorMsg = msg === 'pwgen_error_no_charset' ? $t('pwgen_error_no_charset') : msg;
    }
  }

  async function saveToHistory(pw: string) {
    try {
      const entry = await api.pwgen.add(pw);
      if ($pwSettings.historyLimit !== null) {
        await api.pwgen.trim($pwSettings.historyLimit);
      }
      history = await api.pwgen.list();
      return entry;
    } catch {}
  }

  async function clearHistory() {
    try {
      await api.pwgen.clear();
      history = [];
    } catch {}
  }

  function copyText(text: string) {
    navigator.clipboard.writeText(text);
    clearTimeout(toastTimer);
    toast = $t('pwgen_copied');
    toastTimer = setTimeout(() => (toast = ''), 1800);
  }

  function toggleReveal(id: string) {
    const next = new Set(revealedIds);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    revealedIds = next;
  }

  function formatDate(iso: string) {
    return new Date(iso).toLocaleString('ru-RU', {
      day: '2-digit', month: '2-digit',
      hour: '2-digit', minute: '2-digit',
    });
  }
</script>

<svelte:window onkeydown={onKeydown} />

{#if open}
  <!-- backdrop -->
  <div class="backdrop" role="presentation" onclick={() => (open = false)}></div>

  <aside class="panel">
    <header class="panel-header">
      <span class="panel-title">{$t('pwgen_title')}</span>
      <div class="header-actions">
        <button class="icon-btn" onclick={toggleTheme} title={$t('pwgen_btn_toggle_theme')}>
          {#if $theme === 'dark'}
            <Icon name="sun" size={14} />
          {:else}
            <Icon name="moon" size={14} />
          {/if}
        </button>
        <button class="icon-btn" onclick={() => (open = false)} title={$t('pwgen_btn_close')}>
          <Icon name="x" size={14} />
        </button>
      </div>
    </header>

    <div class="panel-body">
      <!-- Password output -->
      <div class="pw-output">
        <div class="pw-field-wrap">
          <input
            type={showPassword ? 'text' : 'password'}
            class="pw-field"
            readonly
            value={currentPassword || ''}
            placeholder={$t('pwgen_placeholder')}
          />
          {#if currentPassword}
            <button class="icon-btn pw-eye" onclick={() => (showPassword = !showPassword)} title={$t('pwgen_btn_show_hide')}>
              <Icon name={showPassword ? 'eye-off' : 'eye'} size={14} />
            </button>
            <button class="icon-btn pw-copy" onclick={() => copyText(currentPassword)} title={$t('pwgen_btn_copy')}>
              <Icon name="copy" size={14} />
            </button>
          {/if}
        </div>

        {#if errorMsg}
          <div class="error-msg">{errorMsg}</div>
        {/if}

        <button class="btn btn-primary btn-generate" onclick={generate}>
          <Icon name="refresh-cw" size={14} />
          {$t('pwgen_btn_generate')}
        </button>
      </div>

      <!-- Settings -->
      <div class="section">
        <button class="section-toggle" onclick={() => (settingsOpen = !settingsOpen)}>
          <Icon name="settings" size={13} />
          {$t('pwgen_btn_settings')}
          <Icon name={settingsOpen ? 'chevron-right' : 'chevron-right'} size={13} class={settingsOpen ? 'rot90' : ''} />
        </button>

        {#if settingsOpen}
          <div class="settings-body">
            <div class="setting-row">
              <label for="pwgen-length">{$t('pwgen_length')} <strong>{$pwSettings.length}</strong></label>
              <input
                id="pwgen-length"
                type="range" min="8" max="64"
                bind:value={$pwSettings.length}
              />
            </div>

            <div class="checkboxes">
              <label class="cb-label">
                <input type="checkbox" bind:checked={$pwSettings.uppercase} />
                {$t('pwgen_upper')}
              </label>
              <label class="cb-label">
                <input type="checkbox" bind:checked={$pwSettings.lowercase} />
                {$t('pwgen_lower')}
              </label>
              <label class="cb-label">
                <input type="checkbox" bind:checked={$pwSettings.numbers} />
                {$t('pwgen_digits')}
              </label>
              <label class="cb-label">
                <input type="checkbox" bind:checked={$pwSettings.symbols} />
                {$t('pwgen_symbols')}
              </label>
              <label class="cb-label">
                <input type="checkbox" bind:checked={$pwSettings.excludeSimilar} />
                {$t('pwgen_exclude_similar')}
              </label>
            </div>

            <div class="divider"></div>

            <label class="cb-label">
              <input type="checkbox" bind:checked={$pwSettings.historyEnabled} />
              {$t('pwgen_save_history')}
            </label>

            {#if $pwSettings.historyEnabled}
              <div class="setting-row warn-note">
                <Icon name="info" size={13} />
                {$t('pwgen_history_local_note')}
              </div>
              <div class="setting-row">
                <label for="pwgen-hlimit">{$t('pwgen_limit_label')}</label>
                <CustomSelect
                  id="pwgen-hlimit"
                  options={[
                    { label: $t('pwgen_limit_none'), value: 'unlimited' },
                    { label: $t('pwgen_limit_10'), value: '10' },
                    { label: $t('pwgen_limit_25'), value: '25' },
                    { label: $t('pwgen_limit_50'), value: '50' },
                    { label: $t('pwgen_limit_100'), value: '100' },
                  ]}
                  value={$pwSettings.historyLimit === null ? 'unlimited' : String($pwSettings.historyLimit)}
                  onchange={(v) => {
                    pwSettings.update(s => ({ ...s, historyLimit: v === 'unlimited' ? null : Number(v) }));
                  }}
                />
              </div>
            {/if}
          </div>
        {/if}
      </div>

      <!-- History -->
      {#if $pwSettings.historyEnabled}
        <div class="section">
          <div class="section-header-row">
            <span class="section-label">
              <Icon name="clock" size={13} />
              {$t('pwgen_history_title', { n: String(history.length) })}
            </span>
            {#if history.length > 0}
              <button class="btn btn-ghost btn-sm" onclick={clearHistory}>
                <Icon name="trash" size={13} />
                {$t('pwgen_btn_clear')}
              </button>
            {/if}
          </div>

          {#if history.length === 0}
            <p class="empty-note">{$t('pwgen_history_empty')}</p>
          {:else}
            <ul class="history-list">
              {#each history as entry (entry.id)}
                <li class="history-item">
                  <div class="history-pw">
                    {#if revealedIds.has(entry.id)}
                      <span class="pw-text">{entry.password}</span>
                    {:else}
                      <span class="pw-text masked">{'•'.repeat(Math.min(entry.password.length, 20))}</span>
                    {/if}
                    <span class="history-date">{formatDate(entry.created_at)}</span>
                  </div>
                  <div class="history-actions">
                    <button class="icon-btn" onclick={() => toggleReveal(entry.id)} title={$t('pwgen_btn_show_hide')}>
                      <Icon name={revealedIds.has(entry.id) ? 'eye-off' : 'eye'} size={13} />
                    </button>
                    <button class="icon-btn" onclick={() => copyText(entry.password)} title={$t('pwgen_btn_copy')}>
                      <Icon name="copy" size={13} />
                    </button>
                  </div>
                </li>
              {/each}
            </ul>
          {/if}
        </div>
      {/if}
    </div>

    {#if toast}
      <div class="toast">{toast}</div>
    {/if}
  </aside>
{/if}

<style>
  .backdrop {
    position: fixed;
    inset: 0;
    z-index: 100;
    background: rgba(0, 0, 0, 0.35);
  }

  .panel {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    width: 380px;
    z-index: 101;
    background: var(--bg-2);
    border-left: 1px solid var(--border);
    box-shadow: var(--shadow-lg);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: slide-in 0.2s ease;
  }

  @keyframes slide-in {
    from { transform: translateX(100%); opacity: 0; }
    to   { transform: translateX(0);    opacity: 1; }
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 0.875rem;
    height: 44px;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .panel-title {
    font-weight: 600;
    font-size: 0.875rem;
  }

  .header-actions {
    display: flex;
    gap: 0.4rem;
  }

  .panel-body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  /* Password output */
  .pw-output {
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }

  .pw-field-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }

  .pw-field {
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 0.85rem;
    letter-spacing: 0.04em;
    padding-right: 4.5rem;
    background: var(--surface);
    border-color: var(--border-2);
  }

  .pw-eye {
    position: absolute;
    right: 2.25rem;
    background: transparent;
    border: none;
  }

  .pw-copy {
    position: absolute;
    right: 0.25rem;
    background: transparent;
    border: none;
  }

  .btn-generate {
    width: 100%;
    justify-content: center;
    gap: 0.5rem;
  }

  /* Sections */
  .section {
    flex-shrink: 0;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    overflow: hidden;
  }

  .section-toggle {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.55rem 0.75rem;
    background: var(--surface);
    border: none;
    border-radius: 0;
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--text-2);
    text-align: left;
    cursor: pointer;
    transition: background 0.15s;
  }

  .section-toggle:hover { background: var(--surface-2); }

  :global(.rot90) { transform: rotate(90deg); }

  .settings-body {
    padding: 0.75rem;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
    border-top: 1px solid var(--border);
    background: var(--bg);
  }

  .setting-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.8rem;
    color: var(--text-2);
  }

  .setting-row label {
    min-width: 80px;
    flex-shrink: 0;
    font-weight: 500;
    color: var(--text-2);
  }

  .setting-row input[type="range"] {
    flex: 1;
    padding: 0;
    background: transparent;
    border: none;
    accent-color: var(--accent);
  }

  .checkboxes {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
  }

  .cb-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.8rem;
    color: var(--text);
    cursor: pointer;
  }

  .cb-label input[type="checkbox"] {
    width: auto;
    accent-color: var(--accent);
    cursor: pointer;
  }

  .divider {
    height: 1px;
    background: var(--border);
    margin: 0.1rem 0;
  }

  .warn-note {
    background: var(--warn-bg);
    color: var(--warn-text);
    padding: 0.4rem 0.6rem;
    border-radius: var(--radius-sm);
    font-size: 0.75rem;
  }

  /* Section header */
  .section-header-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.5rem 0.75rem;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
  }

  .section-label {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--text-2);
  }

  .empty-note {
    padding: 0.75rem;
    font-size: 0.78rem;
    color: var(--text-3);
    text-align: center;
  }

  /* History */
  .history-list {
    list-style: none;
    display: flex;
    flex-direction: column;
  }

  .history-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.45rem 0.75rem;
    border-top: 1px solid var(--border);
    gap: 0.5rem;
  }

  .history-item:first-child { border-top: none; }

  .history-pw {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
    min-width: 0;
  }

  .pw-text {
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 0.78rem;
    color: var(--text);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 180px;
  }

  .masked { color: var(--text-3); letter-spacing: 0.05em; }

  .history-date {
    font-size: 0.7rem;
    color: var(--text-3);
  }

  .history-actions {
    display: flex;
    gap: 0.3rem;
    flex-shrink: 0;
  }

  /* Toast */
  .toast {
    position: absolute;
    bottom: 1rem;
    left: 50%;
    transform: translateX(-50%);
    background: var(--success);
    color: #fff;
    font-size: 0.78rem;
    font-weight: 600;
    padding: 0.4rem 1rem;
    border-radius: 999px;
    box-shadow: var(--shadow);
    pointer-events: none;
    animation: fade-in 0.15s ease;
    white-space: nowrap;
  }

  @keyframes fade-in {
    from { opacity: 0; transform: translateX(-50%) translateY(4px); }
    to   { opacity: 1; transform: translateX(-50%) translateY(0); }
  }
</style>
