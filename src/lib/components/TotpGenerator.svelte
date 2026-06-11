<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from '$lib/i18n';
  import { totpStore } from '$lib/store/totp.svelte';
  import { workspacesStore } from '$lib/store/workspaces.svelte';
  import { profilesStore } from '$lib/store/profiles.svelte';
  import TotpList from './TotpList.svelte';
  import TotpAddModal from './TotpAddModal.svelte';
  import Icon from '$lib/Icon.svelte';
  import { portal } from '$lib/portal';

  interface Props {
    open?: boolean;
    /** 'global' — no auto-filter; 'workspace' — pre-filter to this workspace with toggle */
    context?: 'global' | 'workspace';
    contextId?: string;
  }

  let { open = $bindable(false), context = 'global', contextId }: Props = $props();

  let search = $state('');
  let showAdd = $state(false);
  /** null = show all; workspace id string = filter to that workspace */
  let activeWorkspace = $state<string | null>(null);

  onMount(() => {
    totpStore.ensureLoaded();
    workspacesStore.ensureLoaded();
    profilesStore.ensureLoaded();
  });

  // When panel opens (or context changes), reset workspace filter
  $effect(() => {
    if (open) {
      activeWorkspace = context === 'workspace' && contextId ? contextId : null;
      totpStore.ensureLoaded();
    }
  });

  const filteredEntries = $derived.by(() => {
    let list = totpStore.list;

    // Workspace filter
    if (activeWorkspace) {
      const profileIds = profilesStore.byWorkspace(activeWorkspace).map((p) => p.id);
      list = totpStore.byWorkspace(activeWorkspace, profileIds);
    }

    // Search filter
    if (search.trim()) {
      const q = search.toLowerCase();
      list = list.filter((e) => {
        if (e.name.toLowerCase().includes(q)) return true;
        if (e.issuer?.toLowerCase().includes(q)) return true;
        if (e.tags.some((tag) => tag.toLowerCase().includes(q))) return true;
        // Also match profile name
        const pTag = e.tags.find((t) => t.startsWith('profile:'));
        if (pTag) {
          const pid = pTag.slice('profile:'.length);
          const pname = profilesStore.list.find((p) => p.id === pid)?.name ?? '';
          if (pname.toLowerCase().includes(q)) return true;
        }
        return false;
      });
    }

    return list;
  });

  function onKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') open = false;
  }

  function toggleWorkspace(id: string) {
    activeWorkspace = activeWorkspace === id ? null : id;
  }
</script>

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
  <div
    class="overlay"
    use:portal
    onclick={(e) => { if (e.target === e.currentTarget) open = false; }}
    onkeydown={onKeydown}
    role="presentation"
    tabindex="-1"
  >
    <div class="panel" role="dialog" aria-label={$t('totp_title')}>
      <div class="panel-header">
        <div class="header-title">
          <Icon name="shield" size={16} />
          <h3>{$t('totp_title')}</h3>
          <span class="count-badge">{filteredEntries.length}</span>
        </div>
        <button class="close-btn" onclick={() => (open = false)}>
          <Icon name="x" size={15} />
        </button>
      </div>

      <div class="panel-search">
        <div class="search-wrap">
          <span class="search-icon"><Icon name="search" size={13} /></span>
          <input
            type="text"
            bind:value={search}
            placeholder={$t('totp_search_placeholder')}
            class="search-input"
          />
        </div>
      </div>

      <!-- Workspace chips -->
      {#if workspacesStore.list.length > 0}
        <div class="ws-chips">
          {#if context === 'workspace'}
            <button
              class="chip-btn"
              class:active={activeWorkspace === null}
              onclick={() => (activeWorkspace = null)}
            >
              {$t('totp_show_all')}
            </button>
          {/if}
          {#each workspacesStore.list as ws (ws.id)}
            <button
              class="chip-btn"
              class:active={activeWorkspace === ws.id}
              onclick={() => toggleWorkspace(ws.id)}
              style="--ws-color: {ws.color}"
            >
              <span class="ws-dot" style="background:{ws.color}"></span>
              {ws.name}
            </button>
          {/each}
        </div>
      {/if}

      <div class="panel-body">
        {#if totpStore.loading && !totpStore.loaded}
          <div class="loading-msg">{$t('loading')}</div>
        {:else}
          <TotpList
            entries={filteredEntries}
            showProfileBadge={true}
            onrequestAdd={() => (showAdd = true)}
          />
        {/if}
      </div>

      <div class="panel-footer">
        <button class="btn-primary" onclick={() => (showAdd = true)}>
          <Icon name="plus" size={13} />
          {$t('totp_btn_add')}
        </button>
      </div>
    </div>
  </div>
{/if}

{#if showAdd}
  <TotpAddModal
    initialTags={context === 'workspace' && contextId ? [`workspace:${contextId}`] : []}
    onclose={() => (showAdd = false)}
  />
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.3);
    z-index: 900;
    display: flex;
    justify-content: flex-end;
  }

  .panel {
    background: var(--bg-2);
    border-left: 1px solid var(--border);
    width: 380px;
    max-width: 95vw;
    height: 100%;
    display: flex;
    flex-direction: column;
    box-shadow: var(--shadow-lg);
    animation: slide-in 0.2s ease;
  }

  @keyframes slide-in {
    from { transform: translateX(100%); }
    to { transform: translateX(0); }
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .header-title {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .header-title h3 {
    margin: 0;
    font-size: 0.95rem;
    font-weight: 600;
  }

  .count-badge {
    background: var(--accent-bg);
    color: var(--accent);
    border: 1px solid var(--accent);
    border-radius: 999px;
    font-size: 0.7rem;
    padding: 0.05rem 0.4rem;
    font-weight: 600;
  }

  .close-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-2);
    display: flex;
    align-items: center;
    padding: 0.2rem;
    border-radius: var(--radius-sm);
    transition: all 0.15s;
  }

  .close-btn:hover { color: var(--text); background: var(--surface); }

  .panel-search {
    padding: 0.75rem 1rem 0;
    flex-shrink: 0;
  }

  .search-wrap {
    position: relative;
  }

  .search-icon {
    position: absolute;
    left: 0.6rem;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-2);
    pointer-events: none;
    display: flex;
  }

  .search-input {
    width: 100%;
    box-sizing: border-box;
    padding: 0.45rem 0.6rem 0.45rem 2rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--text);
    font-size: 0.83rem;
  }

  .search-input:focus { outline: none; border-color: var(--accent); }

  .ws-chips {
    display: flex;
    gap: 0.35rem;
    padding: 0.6rem 1rem;
    flex-wrap: wrap;
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
  }

  .chip-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.25rem 0.6rem;
    font-size: 0.75rem;
    border: 1px solid var(--border);
    border-radius: 999px;
    background: none;
    cursor: pointer;
    color: var(--text-2);
    transition: all 0.15s;
  }

  .chip-btn:hover { border-color: var(--accent); color: var(--accent); }

  .chip-btn.active {
    background: var(--accent-bg);
    border-color: var(--accent);
    color: var(--accent);
  }

  .ws-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .panel-body {
    flex: 1;
    overflow-y: auto;
    padding: 0.75rem 1rem;
  }

  .loading-msg {
    text-align: center;
    padding: 2rem;
    color: var(--text-2);
    font-size: 0.83rem;
  }

  .panel-footer {
    padding: 0.75rem 1rem;
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }

  .btn-primary {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: var(--radius-sm);
    padding: 0.45rem 1rem;
    font-size: 0.83rem;
    cursor: pointer;
    width: 100%;
    justify-content: center;
    transition: background 0.15s;
  }

  .btn-primary:hover { background: var(--accent-hover); }
</style>
