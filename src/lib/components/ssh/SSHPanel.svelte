<script lang="ts">
  import { portal } from '$lib/portal';
  import { onMount, untrack } from 'svelte';
  import { sshStore } from '$lib/store/ssh.svelte';
  import type { SshConnection } from '$lib/types';
  import { api } from '$lib/api';
  import Icon from '$lib/Icon.svelte';
  import SSHConnectionsList from './SSHConnectionsList.svelte';
  import SSHConnectionForm from './SSHConnectionForm.svelte';
  import { t } from '$lib/i18n';

  interface Props {
    open?: boolean;
    /** 'global' | 'workspace' | 'profile' */
    context?: string;
    workspaceId?: string | null;
    profileId?: string | null;
  }

  let {
    open = $bindable(false),
    context = 'global',
    workspaceId = null,
    profileId = null,
  }: Props = $props();

  let editConn = $state<SshConnection | null>(null);
  let showForm = $state(false);
  let showAll = $state(false);
  let connecting = $state<string | null>(null);
  let connectError = $state('');
  let workspaceNames = $state<Record<string, string>>({});

  onMount(() => {
    sshStore.ensureLoaded();
    api.workspaces.list().then((list) => {
      const map: Record<string, string> = {};
      list.forEach((w) => (map[w.id] = w.name));
      workspaceNames = map;
    });
  });

  $effect(() => {
    if (open) {
      untrack(() => {
        showAll = context === 'global';
        sshStore.ensureLoaded();
      });
    }
  });

  // Filtering: in workspace context show global (no ws links) OR linked to this ws
  // In profile context — only linked to this profile
  // In global context — all
  let filteredConnections = $derived(
    showAll
      ? sshStore.connections
      : context === 'profile' && profileId
        ? sshStore.connections.filter((c) => c.profile_ids.includes(profileId!))
        : context === 'workspace' && workspaceId
          ? sshStore.connections.filter(
              (c) => c.workspace_ids.length === 0 || c.workspace_ids.includes(workspaceId!)
            )
          : sshStore.connections
  );

  function handleEdit(conn: SshConnection) {
    editConn = conn;
    showForm = true;
  }

  function handleNew() {
    editConn = null;
    showForm = true;
  }

  function handleFormSave(conn: SshConnection) {
    const idx = sshStore.connections.findIndex((c) => c.id === conn.id);
    if (idx >= 0) {
      sshStore.connections[idx] = conn;
    } else {
      sshStore.connections = [...sshStore.connections, conn];
    }
    showForm = false;
    editConn = null;
  }

  async function handleConnect(conn: SshConnection) {
    connecting = conn.id;
    connectError = '';
    try {
      await sshStore.connect(conn.id);
      open = false;
    } catch (e: unknown) {
      connectError = String(e);
    } finally {
      connecting = null;
    }
  }

  function close() {
    open = false;
    showForm = false;
    editConn = null;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') close();
  }

  let contextLabel = $derived(
    context === 'profile' ? $t('ssh_ctx_profile')
    : context === 'workspace' ? $t('ssh_ctx_workspace')
    : $t('ssh_ctx_global')
  );
</script>

{#if open}
  <div class="overlay" use:portal role="dialog" aria-modal="true">
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div class="backdrop" role="presentation" onclick={close}></div>

    <div class="panel">
      <header class="panel-header">
        <div class="panel-title">
          <Icon name="terminal" size={16} />
          {$t('ssh_title')}
        </div>
        <div class="header-right">
          {#if context !== 'global'}
            <div class="ctx-tabs">
              <button class="tab" class:active={!showAll} onclick={() => (showAll = false)}>
                {contextLabel}
              </button>
              <button class="tab" class:active={showAll} onclick={() => (showAll = true)}>
                {$t('ssh_ctx_all')}
              </button>
            </div>
          {/if}
          <button class="icon-btn" onclick={close} title="Close">
            <Icon name="x" size={16} />
          </button>
        </div>
      </header>

      <div class="panel-body">
        {#if showForm}
          <div class="form-header">
            <button class="btn-ghost btn-sm" onclick={() => { showForm = false; editConn = null; }}>
              <Icon name="arrow-left" size={13} /> {$t('ssh_btn_cancel')}
            </button>
            <span class="form-title">{editConn ? $t('ssh_form_edit') : $t('ssh_form_new')}</span>
          </div>
          <SSHConnectionForm
            connection={editConn}
            defaultWorkspaceId={workspaceId}
            defaultProfileId={profileId}
            onSave={handleFormSave}
            onCancel={() => { showForm = false; editConn = null; }}
          />
        {:else}
          {#if connectError}
            <div class="error-msg">{connectError}</div>
          {/if}

          <div class="list-header">
            <span class="list-count">{$t('ssh_connections_count', { n: String(filteredConnections.length) })}</span>
            <button class="btn-primary btn-sm" onclick={handleNew}>
              <Icon name="plus" size={13} /> {$t('ssh_btn_new')}
            </button>
          </div>

          <SSHConnectionsList
            connections={filteredConnections}
            {workspaceNames}
            onEdit={handleEdit}
            onConnect={handleConnect}
            onOpenTerminal={close}
          />
        {/if}
      </div>
    </div>
  </div>
{/if}

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<svelte:window onkeydown={handleKeydown} />

<style>
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 200;
    display: flex;
    align-items: stretch;
    justify-content: flex-end;
  }
  .backdrop {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.45);
  }
  .panel {
    position: relative;
    width: 480px;
    max-width: 100vw;
    height: 100%;
    background: var(--bg);
    border-left: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: var(--shadow-lg);
  }
  .panel-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }
  .panel-title {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    font-weight: 600;
    font-size: 0.9rem;
    color: var(--text);
    flex: 1;
  }
  .header-right { display: flex; align-items: center; gap: 0.5rem; }
  .ctx-tabs { display: flex; gap: 0.15rem; }
  .tab {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 0.78rem;
    color: var(--text-2);
    padding: 0.2rem 0.5rem;
    border-radius: var(--radius-sm);
    transition: all 0.15s;
  }
  .tab.active { background: var(--accent-bg); color: var(--accent); }
  .tab:hover:not(.active) { background: var(--surface, var(--bg-2)); }
  .panel-body {
    flex: 1;
    overflow-y: auto;
    padding: 0.75rem 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .form-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.25rem;
  }
  .form-title { font-size: 0.875rem; font-weight: 500; color: var(--text); }
  .list-header { display: flex; align-items: center; justify-content: space-between; }
  .list-count { font-size: 0.8rem; color: var(--text-2); }
  .error-msg {
    background: var(--danger-bg);
    color: var(--danger-text);
    border-radius: var(--radius-sm);
    padding: 0.4rem 0.6rem;
    font-size: 0.82rem;
  }
</style>
