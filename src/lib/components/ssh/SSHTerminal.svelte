<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Terminal } from '@xterm/xterm';
  import { FitAddon } from '@xterm/addon-fit';
  import { WebLinksAddon } from '@xterm/addon-web-links';
  import '@xterm/xterm/css/xterm.css';
  import { sshStore } from '$lib/store/ssh.svelte';
  import { api } from '$lib/api';
  import Icon from '$lib/Icon.svelte';
  import { t } from '$lib/i18n';

  interface Props {
    sessionId: string;
    visible?: boolean;
    onMinimize?: () => void;
    onDisconnect?: () => void;
  }

  let { sessionId, visible = true, onMinimize, onDisconnect }: Props = $props();

  let termEl = $state<HTMLDivElement | undefined>(undefined);
  let term: Terminal | null = null;
  let fitAddon: FitAddon | null = null;
  let resizeObserver: ResizeObserver | null = null;

  // Drawer size state
  const SESSION_BAR_H = 34; // px — approximate height of SSHSessionBar
  const DEFAULT_VH = 45;
  let drawerVh = $state(DEFAULT_VH);
  let isMaximized = $state(false);
  let isDragging = $state(false);

  let session = $derived(sshStore.sessionById(sessionId));

  let drawerHeight = $derived(
    isMaximized ? `calc(100vh - 2.5rem)` : `${drawerVh}vh`
  );

  function startDrag(e: MouseEvent) {
    if (isMaximized) return;
    isDragging = true;
    e.preventDefault();

    function onMove(ev: MouseEvent) {
      const newHeight = window.innerHeight - ev.clientY - SESSION_BAR_H;
      const vh = Math.max(20, Math.min(90, (newHeight / window.innerHeight) * 100));
      drawerVh = vh;
    }
    function onUp() {
      isDragging = false;
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
      requestAnimationFrame(() => { fitAddon?.fit(); syncSize(); });
    }
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  }

  function toggleMaximize() {
    isMaximized = !isMaximized;
    requestAnimationFrame(() => requestAnimationFrame(() => {
      fitAddon?.fit();
      syncSize();
    }));
  }

  onMount(() => {    if (!termEl) return;

    term = new Terminal({
      cursorBlink: true,
      fontSize: 13,
      fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', Menlo, Monaco, 'Courier New', monospace",
      theme: {
        background: '#0d1117',
        foreground: '#e2e8f0',
        cursor: '#e2e8f0',
        selectionBackground: '#334155',
      },
      scrollback: 5000,
      allowProposedApi: true,
    });

    fitAddon = new FitAddon();
    term.loadAddon(fitAddon);
    term.loadAddon(new WebLinksAddon());
    term.open(termEl);

    term.onData((data) => {
      const bytes = Array.from(new TextEncoder().encode(data));
      api.ssh.sendData(sessionId, bytes).catch(() => {});
    });

    resizeObserver = new ResizeObserver(() => {
      requestAnimationFrame(() => { fitAddon?.fit(); syncSize(); });
    });
    resizeObserver.observe(termEl);

    // Fit first — get real dimensions, then register and flush buffered data
    requestAnimationFrame(() => requestAnimationFrame(() => {
      fitAddon?.fit();
      syncSize();
      sshStore.registerDataCallback(sessionId, (bytes: Uint8Array) => {
        term?.write(bytes);
      });
    }));
  });

  onDestroy(() => {
    resizeObserver?.disconnect();
    sshStore.unregisterDataCallback(sessionId);
    term?.dispose();
    term = null;
    fitAddon = null;
  });

  // When becoming visible again — refit and repaint
  $effect(() => {
    if (visible && term && fitAddon) {
      requestAnimationFrame(() => requestAnimationFrame(() => {
        fitAddon?.fit();
        term?.refresh(0, term.rows - 1);
        term?.scrollToBottom();
        syncSize();
      }));
    }
  });

  function syncSize() {
    if (!term) return;
    api.ssh.resize(sessionId, term.cols, term.rows).catch(() => {});
  }

  async function disconnect() {
    try {
      await sshStore.disconnect(sessionId);
      await sshStore.removeSession(sessionId);
    } catch {}
    onDisconnect?.();
  }

  async function reconnect() {
    const s = session;
    if (!s) return;
    try {
      const newId = await sshStore.connect(s.connection_id);
      await sshStore.removeSession(sessionId);
      sshStore.activeTerminalId = newId;
      onDisconnect?.();
    } catch {}
  }
</script>

<div class="terminal-drawer" class:hidden={!visible} class:dragging={isDragging} style="height:{drawerHeight}">
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="terminal-wrap">
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="drawer-handle" onmousedown={startDrag}>
      <span class="handle-grip"></span>
    </div>
    <div class="terminal-header">
      <span class="terminal-title">
        <Icon name="terminal" size={12} />
        {session?.connection_name ?? sessionId}
        <span class="host-label">{session ? `${session.host}:${session.port}` : ''}</span>
      </span>
      <div class="terminal-status">
        {#if session?.status === 'connected'}
          <span class="dot green"></span>
        {:else if session?.status === 'connecting'}
          <span class="dot yellow"></span>
        {:else if session?.status === 'error' || session?.status === 'disconnected'}
          <span class="dot red"></span>
        {/if}
      </div>
      <div class="header-actions">
        {#if onMinimize}
          <button class="hbtn" onclick={onMinimize} title={$t('ssh_btn_minimize')}>
            <Icon name="minus" size={13} />
          </button>
        {/if}
        <button class="hbtn" onclick={toggleMaximize} title={isMaximized ? 'Restore' : 'Maximize'}>
          <Icon name={isMaximized ? 'minimize-2' : 'maximize-2'} size={13} />
        </button>
        <button class="hbtn danger" onclick={disconnect} title={$t('ssh_btn_disconnect')}>
          <Icon name="x" size={13} />
        </button>
      </div>
    </div>

    {#if session?.status === 'error' || session?.status === 'disconnected'}
      <div class="disconnected-banner">
        <Icon name="wifi-off" size={13} />
        {session?.error ? $t('ssh_terminal_error', { msg: session.error }) : $t('ssh_terminal_closed')}
        <button class="btn-primary btn-sm" onclick={reconnect}>{$t('ssh_btn_reconnect')}</button>
      </div>
    {/if}

    <div class="xterm-container" bind:this={termEl}></div>
  </div>
</div>

<style>
  .terminal-drawer {
    position: fixed;
    left: 0;
    right: 0;
    bottom: 2.1rem;
    z-index: 300;
    display: flex;
    flex-direction: column;
    transform: translateY(0);
    transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1),
                opacity 0.2s ease,
                height 0.15s ease;
    opacity: 1;
  }
  .terminal-drawer.hidden {
    transform: translateY(104%);
    opacity: 0;
    pointer-events: none;
  }
  /* Suppress height transition while dragging */
  .terminal-drawer.dragging { transition: none; }

  .terminal-wrap {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    background: #0d1117;
    border-top: 2px solid #1e293b;
    box-shadow: 0 -4px 24px rgba(0, 0, 0, 0.5);
    overflow: hidden;
  }

  /* Resize handle */
  .drawer-handle {
    height: 5px;
    background: #0d1117;
    cursor: ns-resize;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.15s;
  }
  .drawer-handle:hover { background: #1a2332; }
  .handle-grip {
    width: 32px;
    height: 2px;
    border-radius: 2px;
    background: #2a3549;
    transition: background 0.15s;
  }
  .drawer-handle:hover .handle-grip { background: #4a5568; }

  /* Compact header */
  .terminal-header {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.2rem 0.5rem 0.2rem 0.75rem;
    background: #0f1923;
    border-bottom: 1px solid #1a2535;
    flex-shrink: 0;
    height: 30px;
  }
  .terminal-title {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    font-size: 0.78rem;
    color: #64748b;
    flex: 1;
    min-width: 0;
  }
  .host-label { color: #374151; font-size: 0.72rem; }
  .terminal-status { display: flex; align-items: center; }
  .dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
  .dot.green { background: #22c55e; }
  .dot.yellow { background: #f59e0b; }
  .dot.red { background: #ef4444; }

  /* Compact action buttons — macOS-style grouping */
  .header-actions {
    display: flex;
    gap: 0;
    align-items: center;
  }
  .hbtn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 22px;
    background: none;
    border: none;
    cursor: pointer;
    color: #475569;
    border-radius: 3px;
    transition: background 0.12s, color 0.12s;
    padding: 0;
  }
  .hbtn:hover { background: #1e293b; color: #94a3b8; }
  .hbtn.danger:hover { background: rgba(239,68,68,0.15); color: #f87171; }

  .disconnected-banner {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.3rem 0.75rem;
    background: rgba(239, 68, 68, 0.1);
    color: #fc8181;
    font-size: 0.78rem;
    border-bottom: 1px solid rgba(239, 68, 68, 0.2);
    flex-shrink: 0;
  }
  .disconnected-banner .btn-primary { margin-left: auto; }

  .xterm-container {
    flex: 1;
    min-height: 0;
    overflow: hidden;
    padding: 0.2rem 0.25rem;
  }
  .xterm-container :global(.xterm) { height: 100%; width: 100%; }
  .xterm-container :global(.xterm-screen) { height: 100%; width: 100%; }
  .xterm-container :global(.xterm-viewport) { overflow-y: auto; }
</style>
