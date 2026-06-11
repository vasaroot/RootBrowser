<script lang="ts">
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import type { Snippet } from 'svelte';
  import { t } from '$lib/i18n';
  import { theme, toggleTheme } from '$lib/theme';
  import Icon from '$lib/Icon.svelte';
  import { api } from '$lib/api';
  import type { Profile } from '$lib/types';
  import PasswordGenerator from '$lib/components/PasswordGenerator.svelte';
  import TotpGenerator from '$lib/components/TotpGenerator.svelte';
  import NotesPanel from '$lib/components/notes/NotesPanel.svelte';
  import SSHPanel from '$lib/components/ssh/SSHPanel.svelte';
  import SSHSessionBar from '$lib/components/ssh/SSHSessionBar.svelte';
  import { sshStore } from '$lib/store/ssh.svelte';
  import { totpStore } from '$lib/store/totp.svelte';
  import { listen } from '@tauri-apps/api/event';
  import { profilesStore } from '$lib/store/profiles.svelte';

  let { children }: { children: Snippet } = $props();

  let runningIds = $state<string[]>([]);
  let pwgenOpen = $state(false);
  let totpOpen = $state(false);
  let notesOpen = $state(false);
  let sshOpen = $state(false);

  let runningProfiles = $derived(
    profilesStore.list.filter((p) => runningIds.includes(p.id))
  );

  async function refreshRunning() {
    try {
      runningIds = await api.profiles.runningIds();
    } catch {}
  }

  function handleKeyBack(e: KeyboardEvent) {
    if (e.altKey && e.key === 'ArrowLeft') {
      e.preventDefault();
      window.history.back();
    }
  }

  function handleMouseBack(e: MouseEvent) {
    if (e.button === 3) {
      e.preventDefault();
      window.history.back();
    }
  }

  onMount(() => {
    const unsub = theme.subscribe((val) => {
      document.body.dataset.theme = val;
    });

    // Preload profiles and TOTP for running indicator and badge resolution
    profilesStore.ensureLoaded();
    totpStore.ensureLoaded();
    sshStore.ensureLoaded();
    refreshRunning();

    // Fallback: refresh on window focus (handles crash/manual kill/hot reload)
    window.addEventListener('focus', refreshRunning);

    // Native back button support for WebKitGTK (Tauri on Linux)
    window.addEventListener('keydown', handleKeyBack);
    window.addEventListener('mouseup', handleMouseBack);

    // Main: react to backend events
    const unlisten = listen<{ running_ids: string[] }>('profiles://running-changed', (e) => {
      runningIds = e.payload.running_ids;
    });

    return () => {
      unsub();
      window.removeEventListener('focus', refreshRunning);
      window.removeEventListener('keydown', handleKeyBack);
      window.removeEventListener('mouseup', handleMouseBack);
      unlisten.then((fn) => fn());
    };
  });

  function isActive(href: string) {
    if (href === '/') return $page.url.pathname === '/';
    return $page.url.pathname.startsWith(href);
  }

  function getWorkspaceHref(p: Profile) {
    return p.workspace_id ? `/workspace/${p.workspace_id}` : '/';
  }
</script>

<div class="layout">
  <header class="topbar">
    <a href="/" class="topbar-brand">
      <img src="/logo.png" alt="RootBrowser" class="brand-logo" />
      <span class="brand-name">Root Browser</span>
    </a>

    <nav class="topbar-nav">
      <a href="/" class="nav-link" class:active={isActive('/')}>
        <Icon name="layers" size={14} />
        {$t('nav_workspaces')}
      </a>
      <a href="/proxies" class="nav-link" class:active={isActive('/proxies')}>
        <Icon name="globe" size={14} />
        {$t('nav_proxies')}
      </a>
      <a href="/settings" class="nav-link" class:active={isActive('/settings')}>
        <Icon name="settings" size={14} />
        {$t('nav_settings')}
      </a>
    </nav>

    <div class="topbar-right">
      <button class="theme-toggle" onclick={() => (totpOpen = !totpOpen)} title={$t('totp_title')}>
        <Icon name="shield" size={14} />
      </button>
      <button class="theme-toggle" onclick={() => (notesOpen = !notesOpen)} title="Notes">
        <Icon name="file-text" size={14} />
      </button>
      <button class="theme-toggle" onclick={() => (sshOpen = !sshOpen)} title={$t('ssh_title')}>
        <Icon name="terminal" size={14} />
      </button>
      <button class="theme-toggle" onclick={() => (pwgenOpen = !pwgenOpen)} title={$t('pwgen_title')}>
        <Icon name="key" size={14} />
      </button>
      <button class="theme-toggle" onclick={toggleTheme} title="Toggle theme">
        {#if $theme === 'dark'}
          <Icon name="sun" size={14} />
        {:else}
          <Icon name="moon" size={14} />
        {/if}
      </button>
    </div>
  </header>

  <main class="content">
    {@render children()}
  </main>

  {#if runningProfiles.length > 0}
    <div class="dock">
      <span class="dock-label">
        <span class="dock-dot"></span>
        {runningProfiles.length} running
      </span>
      <div class="dock-sessions">
        {#each runningProfiles as p (p.id)}
          <a href={getWorkspaceHref(p)} class="dock-item" title={p.name}>
            <Icon name="globe" size={13} />
            <span class="dock-name">{p.name}</span>
          </a>
        {/each}
      </div>
    </div>
  {/if}

  <SSHSessionBar />
</div>

<PasswordGenerator bind:open={pwgenOpen} />
<TotpGenerator bind:open={totpOpen} context="global" />
<NotesPanel bind:open={notesOpen} context="global" />
<SSHPanel bind:open={sshOpen} context="global" />

<style>
  /* ── CSS Variables ── */
  :global([data-theme='dark']) {
    color-scheme: dark;
    --bg:          #0d1117;
    --bg-2:        #161b27;
    --surface:     #1c2333;
    --surface-2:   #232d3f;
    --border:      #2a3549;
    --border-2:    #334155;
    --text:        #e2e8f0;
    --text-2:      #94a3b8;
    --text-3:      #4a5568;
    --accent:      #4f8ef7;
    --accent-hover:#3b7de0;
    --accent-bg:   rgba(79,142,247,0.12);
    --success:     #38a169;
    --success-bg:  rgba(56,161,105,0.15);
    --success-text:#68d391;
    --danger:      #e53e3e;
    --danger-bg:   rgba(229,62,62,0.12);
    --danger-text: #fc8181;
    --warn-bg:     rgba(236,153,75,0.15);
    --warn-text:   #f6ad55;
    --shadow:      0 2px 8px rgba(0,0,0,0.4);
    --shadow-lg:   0 8px 24px rgba(0,0,0,0.5);
    --radius:      10px;
    --radius-sm:   6px;
  }

  :global([data-theme='light']) {
    color-scheme: light;
    --bg:          #f0f4f8;
    --bg-2:        #ffffff;
    --surface:     #ffffff;
    --surface-2:   #f8fafc;
    --border:      #e2e8f0;
    --border-2:    #cbd5e1;
    --text:        #1a202c;
    --text-2:      #4a5568;
    --text-3:      #a0aec0;
    --accent:      #2563eb;
    --accent-hover:#1d4ed8;
    --accent-bg:   rgba(37,99,235,0.08);
    --success:     #16a34a;
    --success-bg:  rgba(22,163,74,0.1);
    --success-text:#15803d;
    --danger:      #dc2626;
    --danger-bg:   rgba(220,38,38,0.08);
    --danger-text: #b91c1c;
    --warn-bg:     rgba(217,119,6,0.1);
    --warn-text:   #b45309;
    --shadow:      0 2px 8px rgba(0,0,0,0.08);
    --shadow-lg:   0 8px 24px rgba(0,0,0,0.12);
    --radius:      10px;
    --radius-sm:   6px;
  }

  :global(*) { box-sizing: border-box; margin: 0; padding: 0; }

  :global(body) {
    font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', sans-serif;
    background: var(--bg);
    color: var(--text);
    height: 100vh;
    overflow: hidden;
    font-size: 14px;
    line-height: 1.5;
    transition: background 0.2s, color 0.2s;
  }

  :global(input, select, textarea) {
    font-family: inherit;
    font-size: 0.875rem;
    background: var(--surface-2);
    border: 1px solid var(--border);
    color: var(--text);
    border-radius: var(--radius-sm);
    padding: 0.5rem 0.75rem;
    width: 100%;
    outline: none;
    transition: border-color 0.15s, box-shadow 0.15s;
  }

  :global(select) {
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2394a3b8' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 0.6rem center;
    padding-right: 2rem;
    cursor: pointer;
  }

  :global(input:focus, select:focus, textarea:focus) {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-bg);
  }

  :global(input::placeholder, textarea::placeholder) { color: var(--text-3); }
  :global(select option) { background: var(--surface); color: var(--text); }

  :global(button) {
    cursor: pointer;
    font-family: inherit;
    font-size: 0.875rem;
    border: none;
    border-radius: var(--radius-sm);
    padding: 0.5rem 1rem;
    transition: all 0.15s;
  }

  :global(button:disabled) { opacity: 0.45; cursor: not-allowed; }

  :global(.btn) {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    text-decoration: none;
    font-family: inherit;
    font-size: 0.875rem;
    font-weight: 500;
    border-radius: var(--radius-sm);
    padding: 0.45rem 1rem;
    border: none;
    cursor: pointer;
    transition: all 0.15s;
    white-space: nowrap;
  }

  :global(.btn:disabled) { opacity: 0.45; cursor: not-allowed; }
  :global(.btn-primary) { background: var(--accent); color: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.2); }
  :global(.btn-primary:hover:not(:disabled)) { background: var(--accent-hover); transform: translateY(-1px); }
  :global(.btn-ghost) { background: transparent; color: var(--text-2); border: 1px solid var(--border); }
  :global(.btn-ghost:hover:not(:disabled)) { background: var(--surface-2); color: var(--text); border-color: var(--border-2); }
  :global(.btn-success) { background: var(--success); color: #fff; }
  :global(.btn-success:hover:not(:disabled)) { filter: brightness(1.1); transform: translateY(-1px); }
  :global(.btn-danger) { background: var(--danger); color: #fff; }
  :global(.btn-danger:hover:not(:disabled)) { filter: brightness(1.1); transform: translateY(-1px); }
  :global(.btn-sm) { padding: 0.3rem 0.65rem; font-size: 0.78rem; }

  :global(.form-group) { display: flex; flex-direction: column; gap: 0.35rem; }
  :global(.form-group label) { font-size: 0.75rem; font-weight: 600; color: var(--text-2); text-transform: uppercase; letter-spacing: 0.05em; }
  :global(.form-row) { display: grid; grid-template-columns: 1fr 1fr; gap: 0.875rem; }

  :global(.error-msg) {
    color: var(--danger-text);
    font-size: 0.8rem;
    padding: 0.5rem 0.75rem;
    background: var(--danger-bg);
    border-radius: var(--radius-sm);
    border: 1px solid color-mix(in srgb, var(--danger) 30%, transparent);
  }

  :global(.icon-btn) {
    display: inline-flex; align-items: center; justify-content: center;
    width: 30px; height: 30px; border-radius: var(--radius-sm);
    background: var(--surface-2); border: 1px solid var(--border);
    color: var(--text-2); cursor: pointer; transition: all 0.15s;
    text-decoration: none;
  }
  :global(.icon-btn:hover:not(:disabled)) { background: var(--surface); border-color: var(--border-2); color: var(--text); }
  :global(.icon-btn:disabled) { opacity: 0.4; cursor: not-allowed; }
  :global(.icon-btn.success) { color: var(--success-text); background: var(--success-bg); border-color: color-mix(in srgb, var(--success) 25%, var(--border)); }
  :global(.icon-btn.success:hover:not(:disabled)) { filter: brightness(1.1); }
  :global(.icon-btn.danger) { color: var(--danger-text); background: var(--danger-bg); border-color: color-mix(in srgb, var(--danger) 25%, var(--border)); }
  :global(.icon-btn.danger:hover:not(:disabled)) { filter: brightness(1.1); }
  :global(.icon-btn.danger-soft:hover:not(:disabled)) { background: var(--danger-bg); border-color: color-mix(in srgb, var(--danger) 30%, var(--border)); color: var(--danger-text); }

  /* ── Layout ── */
  .layout {
    display: flex;
    flex-direction: column;
    height: 100vh;
  }

  /* ── Top Bar ── */
  .topbar {
    height: 44px;
    background: var(--bg-2);
    border-bottom: 1px solid var(--border);
    display: flex;
    align-items: center;
    padding: 0 1rem;
    gap: 1.5rem;
    flex-shrink: 0;
    box-shadow: var(--shadow);
    z-index: 10;
  }

  .topbar-brand {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    text-decoration: none;
    color: var(--text);
    flex-shrink: 0;
  }

  .brand-logo {
    width: 24px;
    height: 24px;
    object-fit: contain;
    border-radius: 6px;
  }

  .brand-name {
    font-weight: 700;
    font-size: 0.875rem;
    letter-spacing: -0.01em;
  }

  .topbar-nav {
    display: flex;
    align-items: center;
    gap: 0.2rem;
    flex: 1;
  }

  .nav-link {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.35rem 0.75rem;
    border-radius: var(--radius-sm);
    text-decoration: none;
    color: var(--text-2);
    font-size: 0.825rem;
    font-weight: 500;
    transition: all 0.15s;
  }

  .nav-link:hover { background: var(--surface); color: var(--text); }
  .nav-link.active { background: var(--accent-bg); color: var(--accent); }

  .topbar-right {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-left: auto;
  }

  .theme-toggle {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 30px;
    height: 30px;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--text-2);
    cursor: pointer;
    transition: all 0.15s;
  }
  .theme-toggle:hover { background: var(--surface); color: var(--text); }

  /* ── Content ── */
  .content {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem 1.75rem;
    background: var(--bg);
    min-height: 0;
  }

  /* ── Dock ── */
  .dock {
    height: 36px;
    background: var(--bg-2);
    border-top: 1px solid var(--border);
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0 1rem;
    flex-shrink: 0;
    overflow: hidden;
  }

  .dock-label {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.72rem;
    color: var(--text-2);
    white-space: nowrap;
    flex-shrink: 0;
  }

  .dock-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--success);
    animation: pulse 2s infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.4; }
  }

  .dock-sessions {
    display: flex;
    gap: 0.35rem;
    overflow-x: auto;
    flex: 1;
  }

  .dock-sessions::-webkit-scrollbar { display: none; }

  .dock-item {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.2rem 0.55rem;
    background: var(--success-bg);
    border: 1px solid color-mix(in srgb, var(--success) 25%, var(--border));
    border-radius: 999px;
    font-size: 0.72rem;
    color: var(--success-text);
    white-space: nowrap;
    text-decoration: none;
    transition: filter 0.15s;
    flex-shrink: 0;
  }

  .dock-item:hover { filter: brightness(1.15); }
  .dock-name { max-width: 100px; overflow: hidden; text-overflow: ellipsis; }
</style>
