<script lang="ts">
  import type { NoteListItem, NoteTag, NoteFolder } from '$lib/types';
  import Icon from '$lib/Icon.svelte';
  import { workspacesStore } from '$lib/store/workspaces.svelte';
  import { profilesStore } from '$lib/store/profiles.svelte';
  import { notesStore } from '$lib/store/notes.svelte';
  import { t } from '$lib/i18n';

  const TAG_COLORS = [
    '#6366f1', '#3b82f6', '#06b6d4', '#10b981',
    '#f59e0b', '#ef4444', '#ec4899', '#8b5cf6',
  ];

  interface Props {
    notes: NoteListItem[];
    allTags: NoteTag[];
    folders: NoteFolder[];
    activeFilter: { type: string; id?: string };
    onfilter: (filter: { type: string; id?: string }) => void;
  }

  let { notes, allTags, folders, activeFilter, onfilter }: Props = $props();

  // ── Collapsed state ────────────────────────────────────────────────────────
  let collapsedWs     = $state<Set<string>>(new Set());
  let collapsedGroups = $state<Set<string>>(new Set());

  // ── Create-tag popup ───────────────────────────────────────────────────────
  let popupOpen     = $state(false);
  let popupPrefix   = $state('');      // pre-filled group prefix, e.g. "Работа/"
  let popupInput    = $state('');
  let popupColor    = $state(TAG_COLORS[0]);
  let popupInputEl  = $state<HTMLInputElement | null>(null);
  let creating      = $state(false);

  // ── Inline edit ────────────────────────────────────────────────────────────
  let editTagId  = $state<string | null>(null);
  let editName   = $state('');
  let editColor  = $state('');

  function openPopup(prefix = '') {
    popupPrefix  = prefix;
    popupInput   = prefix;
    popupColor   = TAG_COLORS[0];
    popupOpen    = true;
    setTimeout(() => popupInputEl?.focus(), 50);
  }

  function closePopup() {
    popupOpen   = false;
    popupInput  = '';
    popupPrefix = '';
  }


  // Only show color row + create-btn when the typed value would create a NEW tag
  const popupIsNew = $derived(
    popupInput.trim().length > 0 &&
    !allTags.some(t => t.name === popupInput.trim())
  );

  // Suggestions: existing tags matching the typed part (after the prefix)
  const popupSuggestions = $derived(
    allTags
      .filter(t => t.name.toLowerCase().includes(popupInput.toLowerCase()) && popupInput.trim().length > 0)
      .slice(0, 6)
  );

  async function createTag() {
    const name = popupInput.trim();
    if (!name || creating) return;
    creating = true;
    try {
      const tag = await notesStore.createTag(name, popupColor);
      closePopup();
      onfilter({ type: 'tag', id: tag.name });
    } finally {
      creating = false;
    }
  }

  function onPopupKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && popupInput.trim()) { e.preventDefault(); void createTag(); }
    if (e.key === 'Escape') closePopup();
  }

  // ── Inline edit handlers ───────────────────────────────────────────────────
  function startEdit(tag: NoteTag, e: MouseEvent) {
    e.stopPropagation();
    editTagId = tag.id;
    editName  = tag.name;
    editColor = tag.color;
  }

  async function saveEdit(e?: KeyboardEvent | MouseEvent) {
    if (e instanceof KeyboardEvent && e.key !== 'Enter') return;
    if (!editTagId || !editName.trim()) return;
    await notesStore.updateTag(editTagId, editName.trim(), editColor);
    editTagId = null;
  }

  async function deleteTag(tag: NoteTag, e: MouseEvent) {
    e.stopPropagation();
    await notesStore.deleteTag(tag.id);
    if (activeFilter.type === 'tag' && activeFilter.id === tag.name) {
      onfilter({ type: 'all' });
    }
  }

  // ── Folder state ──────────────────────────────────────────────────────────
  let collapsedFolders = $state<Set<string>>(new Set());
  let folderModalOpen = $state(false);
  let folderModalParentId = $state<string>('');
  let folderInput = $state('');
  let folderColor = $state(TAG_COLORS[0]);
  let folderInputEl = $state<HTMLInputElement | null>(null);
  let creatingFolder = $state(false);

  // Edit folder inline
  let editFolderId = $state<string | null>(null);
  let editFolderName = $state('');
  let editFolderColor = $state('');

  function openFolderModal(parentId = '') {
    folderModalParentId = parentId;
    folderInput = '';
    folderColor = TAG_COLORS[0];
    folderModalOpen = true;
    setTimeout(() => folderInputEl?.focus(), 50);
  }

  function closeFolderModal() {
    folderModalOpen = false;
    folderInput = '';
  }

  function toggleFolder(id: string) {
    const next = new Set(collapsedFolders);
    if (next.has(id)) next.delete(id); else next.add(id);
    collapsedFolders = next;
  }

  async function createFolder() {
    if (!folderInput.trim() || creatingFolder) return;
    creatingFolder = true;
    try {
      const parentId = folderModalParentId || undefined;
      const f = await notesStore.createFolder(folderInput.trim(), parentId, folderColor);
      closeFolderModal();
      onfilter({ type: 'folder', id: f.id });
    } finally {
      creatingFolder = false;
    }
  }

  function onFolderModalKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && folderInput.trim()) { e.preventDefault(); void createFolder(); }
    if (e.key === 'Escape') closeFolderModal();
  }

  function startEditFolder(f: NoteFolder, e: MouseEvent) {
    e.stopPropagation();
    editFolderId = f.id;
    editFolderName = f.name;
    editFolderColor = f.color;
  }

  async function saveEditFolder(e?: KeyboardEvent | MouseEvent) {
    if (e instanceof KeyboardEvent && e.key !== 'Enter') return;
    if (!editFolderId || !editFolderName.trim()) return;
    await notesStore.updateFolder(editFolderId, editFolderName.trim(), editFolderColor);
    editFolderId = null;
  }

  async function deleteFolder(f: NoteFolder, e: MouseEvent) {
    e.stopPropagation();
    await notesStore.deleteFolder(f.id);
    if (activeFilter.type === 'folder' && activeFilter.id === f.id) {
      onfilter({ type: 'all' });
    }
  }

  // Build folder tree from flat list
  interface FolderNode {
    folder: NoteFolder;
    children: FolderNode[];
    noteCount: number;
  }

  const folderTree = $derived.by((): FolderNode[] => {
    const nodeMap = new Map<string, FolderNode>();
    for (const f of folders) {
      nodeMap.set(f.id, { folder: f, children: [], noteCount: 0 });
    }
    // Count notes per folder
    for (const note of notes) {
      if (note.folder_id && nodeMap.has(note.folder_id)) {
        nodeMap.get(note.folder_id)!.noteCount++;
      }
    }
    const roots: FolderNode[] = [];
    for (const f of folders) {
      const node = nodeMap.get(f.id)!;
      if (f.parent_id && nodeMap.has(f.parent_id)) {
        nodeMap.get(f.parent_id)!.children.push(node);
      } else {
        roots.push(node);
      }
    }
    roots.sort((a, b) => a.folder.name.localeCompare(b.folder.name));
    for (const node of nodeMap.values()) {
      node.children.sort((a, b) => a.folder.name.localeCompare(b.folder.name));
    }
    return roots;
  });

  // ── Workspace / misc helpers ───────────────────────────────────────────────
  function toggleWs(id: string) {
    const next = new Set(collapsedWs);
    if (next.has(id)) next.delete(id); else next.add(id);
    collapsedWs = next;
  }

  function toggleGroup(path: string) {
    const next = new Set(collapsedGroups);
    if (next.has(path)) next.delete(path); else next.add(path);
    collapsedGroups = next;
  }

  function isGlobal(bindings: string[]): boolean {
    return !bindings.some(b => b.startsWith('workspace:') || b.startsWith('profile:'));
  }

  const countAll      = $derived(notes.filter(n => !n.archived).length);
  const countGlobal   = $derived(notes.filter(n => isGlobal(n.bindings) && !n.archived).length);
  const countPinned   = $derived(notes.filter(n => n.pinned && !n.archived).length);
  const countArchived = $derived(notes.filter(n => n.archived).length);

  // ── Tag counts ─────────────────────────────────────────────────────────────
  const countMap = $derived.by((): Map<string, number> => {
    const m = new Map<string, number>();
    for (const note of notes) {
      if (note.archived) continue;
      for (const tag of note.tags) {
        m.set(tag.name, (m.get(tag.name) ?? 0) + 1);
      }
    }
    return m;
  });

  // ── Tag tree ───────────────────────────────────────────────────────────────
  interface TreeNode {
    label: string;
    fullPath: string;
    tag: NoteTag | null;
    children: TreeNode[];
  }

  const tagTree = $derived.by((): TreeNode[] => {
    const tagByName = new Map<string, NoteTag>(allTags.map(t => [t.name, t]));
    const nodeMap   = new Map<string, TreeNode>();

    function getOrCreate(path: string): TreeNode {
      if (nodeMap.has(path)) return nodeMap.get(path)!;
      const parts = path.split('/');
      const node: TreeNode = {
        label:    parts[parts.length - 1],
        fullPath: path,
        tag:      tagByName.get(path) ?? null,
        children: [],
      };
      nodeMap.set(path, node);
      return node;
    }

    const roots       = new Map<string, TreeNode>();

    for (const tag of allTags) {
      const parts = tag.name.split('/');
      if (parts.length === 1) {
        if (!roots.has(tag.name)) roots.set(tag.name, getOrCreate(tag.name));
      } else {
        const rootKey = parts[0];
        if (!roots.has(rootKey)) roots.set(rootKey, getOrCreate(rootKey));
        for (let i = 1; i < parts.length; i++) {
          const parentPath = parts.slice(0, i).join('/');
          const childPath  = parts.slice(0, i + 1).join('/');
          const parent     = getOrCreate(parentPath);
          const child      = getOrCreate(childPath);
          if (!parent.children.some(c => c.fullPath === childPath)) {
            parent.children.push(child);
          }
        }
      }
    }

    return [...roots.values()].sort((a, b) => a.label.localeCompare(b.label));
  });

  // ── Workspace tree ─────────────────────────────────────────────────────────
  const workspaceTree = $derived.by(() =>
    workspacesStore.list.map(ws => {
      const wsTag   = `workspace:${ws.id}`;
      const wsNotes = notes.filter(n =>
        n.bindings.includes(wsTag) &&
        !n.bindings.some(b => b.startsWith('profile:')) &&
        !n.archived
      );
      const profiles = profilesStore.byWorkspace(ws.id).map(p => {
        const pNotes = notes.filter(n => n.bindings.includes(`profile:${p.id}`) && !n.archived);
        return { ...p, noteCount: pNotes.length };
      }).filter(p => p.noteCount > 0);
      return { ...ws, noteCount: wsNotes.length, profiles };
    }).filter(ws => ws.noteCount > 0 || ws.profiles.length > 0)
  );

  function isActive(type: string, id?: string) {
    return activeFilter.type === type && activeFilter.id === id;
  }

  function filterClass(type: string, id?: string) {
    return isActive(type, id) ? 'nav-item active' : 'nav-item';
  }

  function nodeCount(path: string, hasChildren: boolean): number {
    if (!hasChildren) return countMap.get(path) ?? 0;
    let total = 0;
    for (const [name, c] of countMap) {
      if (name === path || name.startsWith(path + '/')) total += c;
    }
    return total;
  }
</script>

<svelte:window onkeydown={(e) => e.key === 'Escape' && closePopup()} />

{#snippet folderNode(node: FolderNode, depth: number)}
  {@const f = node.folder}
  {@const collapsed = collapsedFolders.has(f.id)}

  <div class="folder-node">
    {#if editFolderId === f.id}
      <div class="tag-edit-row" style="padding-left: {depth * 1.5 + 0.5}rem">
        <input type="color" bind:value={editFolderColor} class="tag-color-pick" />
        <input
          type="text"
          bind:value={editFolderName}
          class="tag-edit-input"
          placeholder={f.name}
          onkeydown={(e) => { if (e.key === 'Enter') saveEditFolder(e); if (e.key === 'Escape') editFolderId = null; }}
        />
        <button class="btn-icon-xs btn-save" onclick={saveEditFolder} disabled={!editFolderName.trim()}>
          <Icon name="check" size={11} />
        </button>
        <button class="btn-icon-xs btn-cancel" onclick={() => editFolderId = null}>
          <Icon name="x" size={11} />
        </button>
      </div>
    {:else}
      <div class="folder-node-row">
        <button
          class="{filterClass('folder', f.id)} folder-item"
          style="padding-left: {depth * 1.5 + 0.35}rem"
          onclick={() => onfilter({ type: 'folder', id: f.id })}
        >
          <span class="tag-dot" style="background:{f.color}"></span>
          <span class="tag-name">{f.name}</span>
          {#if node.noteCount > 0}<span class="count">{node.noteCount}</span>{/if}
        </button>

        {#if node.children.length > 0}
          <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
          <span class="collapse-trigger" role="button" tabindex="0"
            onclick={(e) => { e.stopPropagation(); toggleFolder(f.id); }}
            onkeydown={(e) => e.key === 'Enter' && toggleFolder(f.id)}
          >
            <Icon name={collapsed ? 'chevron-right' : 'chevron-down'} size={10} />
          </span>
        {/if}

        <div class="tag-actions">
          <button class="tag-action-btn" onclick={() => openFolderModal(f.id)} title="Добавить подпапку">
            <Icon name="folder-plus" size={10} />
          </button>
          <button class="tag-action-btn" onclick={(e) => startEditFolder(f, e)} title="Переименовать">
            <Icon name="pencil" size={10} />
          </button>
          <button class="tag-action-btn tag-action-del" onclick={(e) => deleteFolder(f, e)} title="Удалить">
            <Icon name="trash-2" size={10} />
          </button>
        </div>
      </div>

      {#if !collapsed && node.children.length > 0}
        {#each node.children as child (child.folder.id)}
          {@render folderNode(child, depth + 1)}
        {/each}
      {/if}
    {/if}
  </div>
{/snippet}

{#snippet treeNode(node: TreeNode, depth: number)}
  {@const hasChildren = node.children.length > 0}
  {@const count       = nodeCount(node.fullPath, hasChildren)}
  {@const collapsed   = collapsedGroups.has(node.fullPath)}
  {@const filterType  = hasChildren ? 'tag-group' : 'tag'}

  {#if editTagId !== null && node.tag?.id === editTagId}
    <div class="tag-edit-row" style="padding-left: {depth * 0.875 + 0.5}rem">
      <input type="color" bind:value={editColor} class="tag-color-pick" title={$t('notes_areas_color')} />
      <input
        type="text"
        bind:value={editName}
        class="tag-edit-input"
        placeholder={node.label}
        onkeydown={(e) => { if (e.key === 'Enter') saveEdit(e); if (e.key === 'Escape') editTagId = null; }}
      />
      <button class="btn-icon-xs btn-save" onclick={saveEdit} disabled={!editName.trim()} title={$t('notes_tag_save')}>
        <Icon name="check" size={11} />
      </button>
      <button class="btn-icon-xs btn-cancel" onclick={() => editTagId = null} title="Отмена">
        <Icon name="x" size={11} />
      </button>
    </div>
  {:else}
    <div class="tag-row" style="padding-left: {depth * 0.875}rem">
      {#if hasChildren}
        <button class="collapse-trigger" onclick={(e) => { e.stopPropagation(); toggleGroup(node.fullPath); }}>
          <Icon name={collapsed ? 'chevron-right' : 'chevron-down'} size={10} />
        </button>
      {:else}
        <span class="tag-indent"></span>
      {/if}

      <button
        class={filterClass(filterType, node.fullPath)}
        onclick={() => onfilter({ type: filterType, id: node.fullPath })}
      >
        <span class="tag-dot" style="background:{node.tag?.color ?? 'var(--text-3)'}; opacity:{node.tag ? 1 : 0.4}"></span>
        <span class="tag-name">{node.label}</span>
        {#if count > 0}<span class="count">{count}</span>{/if}
      </button>

      {#if node.tag}
        <div class="tag-actions">
          <button class="tag-action-btn" onclick={(e) => startEdit(node.tag!, e)} title={$t('notes_tag_rename')}>
            <Icon name="pencil" size={10} />
          </button>
          <button class="tag-action-btn tag-action-del" onclick={(e) => deleteTag(node.tag!, e)} title={$t('notes_tag_delete')}>
            <Icon name="trash-2" size={10} />
          </button>
        </div>
      {/if}
    </div>

    {#if hasChildren && !collapsed}
      {#each node.children as child (child.fullPath)}
        {@render treeNode(child, depth + 1)}
      {/each}
      <div class="group-add-row" style="padding-left: {(depth + 1) * 0.875 + 1.25}rem">
        <button class="btn-group-add" onclick={() => openPopup(node.fullPath + '/')}>
          <Icon name="plus" size={10} />
          <span>в «{node.label}»</span>
        </button>
      </div>
    {/if}
  {/if}
{/snippet}

<div class="filters">
  <!-- Base filters -->
  <div class="filter-section">
    <button class={filterClass('all')} onclick={() => onfilter({ type: 'all' })}>
      <Icon name="file-text" size={13} />
      {$t('notes_filter_all')}
      <span class="count">{countAll}</span>
    </button>
    <button class={filterClass('global')} onclick={() => onfilter({ type: 'global' })}>
      <Icon name="globe" size={13} />
      {$t('notes_filter_global')}
      <span class="count">{countGlobal}</span>
    </button>
    <button class={filterClass('pinned')} onclick={() => onfilter({ type: 'pinned' })}>
      <Icon name="pin" size={13} />
      {$t('notes_filter_pinned')}
      <span class="count">{countPinned}</span>
    </button>
    <button class={filterClass('archived')} onclick={() => onfilter({ type: 'archived' })}>
      <Icon name="archive" size={13} />
      {$t('notes_filter_archived')}
      <span class="count">{countArchived}</span>
    </button>
  </div>

  <!-- Workspace tree -->
  {#if workspaceTree.length > 0}
    <div class="filter-section">
      <div class="section-label">{$t('notes_filter_workspaces')}</div>
      {#each workspaceTree as ws (ws.id)}
        <div class="ws-node">
          <div class="ws-node-row">
            <button class="{filterClass('workspace', ws.id)} ws-item" onclick={() => onfilter({ type: 'workspace', id: ws.id })}>
              <span class="ws-dot" style="background:{ws.color}"></span>
              <span class="ws-name">{ws.name}</span>
              {#if ws.noteCount > 0}<span class="count">{ws.noteCount}</span>{/if}
            </button>
            {#if ws.profiles.length > 0}
              <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
              <span class="collapse-trigger" role="button" tabindex="0"
                onclick={(e) => { e.stopPropagation(); toggleWs(ws.id); }}
                onkeydown={(e) => e.key === 'Enter' && toggleWs(ws.id)}
              >
                <Icon name={collapsedWs.has(ws.id) ? 'chevron-right' : 'chevron-down'} size={10} />
              </span>
            {/if}
          </div>
          {#if !collapsedWs.has(ws.id)}
            {#each ws.profiles as p (p.id)}
              <button class="{filterClass('profile', p.id)} profile-item" onclick={() => onfilter({ type: 'profile', id: p.id })}>
                <Icon name="user" size={11} />
                <span class="p-name">{p.name}</span>
                <span class="count">{p.noteCount}</span>
              </button>
            {/each}
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  <!-- Folders section -->
  <div class="filter-section">
    <div class="section-label-row">
      <span class="section-label">Папки</span>
      <button class="btn-add-area" onclick={() => openFolderModal()} title="Новая папка">
        <Icon name="plus" size={11} />
      </button>
    </div>

    {#each folderTree as node (node.folder.id)}
      {@render folderNode(node, 0)}
    {/each}

    {#if folderTree.length === 0}
      <span class="areas-empty">Папок пока нет</span>
    {/if}
  </div>

  <!-- Tags section -->
  <div class="filter-section">
    <div class="section-label-row">
      <span class="section-label">{$t('notes_areas_title')}</span>
      <button
        class="btn-add-area"
        onclick={() => openPopup()}
        title={$t('notes_areas_new')}
      >
        <Icon name="plus" size={11} />
      </button>
    </div>

    <!-- Tag tree -->
    {#each tagTree as node (node.fullPath)}
      {@render treeNode(node, 0)}
    {/each}

    {#if tagTree.length === 0}
      <span class="areas-empty">{$t('notes_areas_empty')}</span>
    {/if}
  </div>
</div>

<!-- Create-tag modal -->
{#if popupOpen}
<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
  <div class="modal-overlay" onclick={closePopup} role="presentation" tabindex="-1">
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
    <div class="tag-modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
      <div class="tag-modal-header">
        <span class="tag-modal-title">
          {popupPrefix ? `Тег в «${popupPrefix.replace('/', '')}»` : 'Новый тег'}
        </span>
        <button class="btn-icon-xs btn-cancel" onclick={closePopup}><Icon name="x" size={13} /></button>
      </div>

      {#if !popupPrefix}
        <p class="popup-hint">Используй «/» для подгрупп: <code>Группа/тег</code></p>
      {/if}

      <input
        bind:this={popupInputEl}
        bind:value={popupInput}
        type="text"
        class="popup-input"
        placeholder={popupPrefix ? `${popupPrefix}название` : 'название тега'}
        onkeydown={onPopupKeydown}
      />

      {#if popupSuggestions.length > 0}
        <div class="suggestions">
          {#each popupSuggestions as s (s.id)}
            <button class="sug-item" onmousedown={(e) => { e.preventDefault(); onfilter({ type: 'tag', id: s.name }); closePopup(); }}>
              <span class="sug-dot" style="background:{s.color}"></span>
              {s.name}
            </button>
          {/each}
        </div>
      {/if}

      {#if popupIsNew}
        <div class="color-row">
          {#each TAG_COLORS as c}
            <button class="color-swatch" class:active={popupColor === c} style="background:{c}" onclick={() => popupColor = c}></button>
          {/each}
          <label class="color-swatch color-swatch-custom" class:active={!TAG_COLORS.includes(popupColor)} title="Свой цвет">
            <input type="color" bind:value={popupColor} />
            {#if !TAG_COLORS.includes(popupColor)}
              <span class="custom-dot" style="background:{popupColor}"></span>
            {/if}
          </label>
        </div>
        <button class="create-btn" onclick={createTag} disabled={creating}>
          {creating ? '…' : `Создать «${popupInput.trim()}»`}
        </button>
      {/if}
    </div>
  </div>
{/if}

<!-- Create-folder modal -->
{#if folderModalOpen}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
  <div class="modal-overlay" onclick={closeFolderModal} role="presentation" tabindex="-1">
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
    <div class="tag-modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
      <div class="tag-modal-header">
        <span class="tag-modal-title">Новая папка</span>
        <button class="btn-icon-xs btn-cancel" onclick={closeFolderModal}><Icon name="x" size={13} /></button>
      </div>

      <input
        bind:this={folderInputEl}
        bind:value={folderInput}
        type="text"
        class="popup-input"
        placeholder="название папки"
        onkeydown={onFolderModalKeydown}
      />

      <!-- Parent folder selector -->
      <div class="parent-select-row">
        <span class="parent-select-label">Вложить в:</span>
        <select
          class="parent-select"
          value={folderModalParentId}
          onchange={(e) => { folderModalParentId = (e.target as HTMLSelectElement).value; }}
        >
          <option value="">— корневая —</option>
          {#each folders as f (f.id)}
            <option value={f.id}>{f.name}</option>
          {/each}
        </select>
      </div>

      <div class="color-row">
        {#each TAG_COLORS as c}
          <button class="color-swatch" class:active={folderColor === c} style="background:{c}" onclick={() => folderColor = c}></button>
        {/each}
        <label class="color-swatch color-swatch-custom" class:active={!TAG_COLORS.includes(folderColor)} title="Свой цвет">
          <input type="color" bind:value={folderColor} />
          {#if !TAG_COLORS.includes(folderColor)}
            <span class="custom-dot" style="background:{folderColor}"></span>
          {/if}
        </label>
      </div>

      <button class="create-btn" onclick={createFolder} disabled={!folderInput.trim() || creatingFolder}>
        {creatingFolder ? '…' : `Создать «${folderInput.trim() || 'папку'}»`}
      </button>
    </div>
  </div>
{/if}

<style>
  .filters {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.5rem 0;
    overflow-y: auto;
  }

  .filter-section + .filter-section {
    border-top: 1px solid var(--border);
    margin-top: 0.25rem;
    padding-top: 0.25rem;
  }

  .filter-section {
    display: flex;
    flex-direction: column;
    padding: 0 0.5rem;
    gap: 0.1rem;
  }

  .section-label {
    font-size: 0.68rem;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-3);
    padding: 0.6rem 0.5rem 0.2rem;
    font-weight: 600;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.35rem 0.5rem;
    border: none;
    background: none;
    cursor: pointer;
    color: var(--text-2);
    font-size: 0.82rem;
    border-radius: var(--radius-sm);
    text-align: left;
    transition: background 0.1s, color 0.1s;
    width: 100%;
    min-width: 0;
  }

  .nav-item:hover  { background: var(--surface); color: var(--text); }
  .nav-item.active { background: var(--accent-bg); color: var(--accent); }

  .count {
    margin-left: auto;
    font-size: 0.7rem;
    color: var(--text-3);
    background: var(--surface-2);
    padding: 0.05rem 0.35rem;
    border-radius: 999px;
    flex-shrink: 0;
  }
  .nav-item.active .count { background: var(--accent-bg); color: var(--accent); }

  /* Workspace tree */
  .ws-node     { display: flex; flex-direction: column; }
  .ws-node-row { display: flex; align-items: center; }
  .ws-item     { flex: 1; min-width: 0; }

  /* Folder tree (same pattern as workspace) */
  .folder-node     { display: flex; flex-direction: column; }
  .folder-node-row { display: flex; align-items: center; }
  .folder-item     { flex: 1; min-width: 0; }

  .ws-dot {
    width: 8px; height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .ws-name, .p-name, .tag-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    min-width: 0;
  }

  .collapse-trigger {
    cursor: pointer;
    color: var(--text-3);
    padding: 0 0.25rem;
    display: flex;
    align-items: center;
    flex-shrink: 0;
    font-size: 0;
    background: none;
    border: none;
  }

  .profile-item { padding-left: 1.5rem; font-size: 0.78rem; }

  /* Tag tree */
  .tag-row {
    display: flex;
    align-items: center;
    position: relative;
  }
  .tag-row:hover .tag-actions { opacity: 1; }

  .tag-indent { width: 1.25rem; flex-shrink: 0; }

  .tag-dot {
    width: 8px; height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .tag-actions {
    display: flex;
    align-items: center;
    gap: 0.1rem;
    opacity: 0;
    transition: opacity 0.1s;
    flex-shrink: 0;
    margin-right: 0.25rem;
  }

  .tag-action-btn {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-3);
    padding: 0.15rem;
    border-radius: 3px;
    display: flex;
    align-items: center;
  }
  .tag-action-btn:hover     { color: var(--text); background: var(--surface-2); }
  .tag-action-del:hover     { color: var(--danger, #ef4444); }

  /* Inline edit */
  .tag-edit-row {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    padding-top: 0.15rem;
    padding-bottom: 0.15rem;
    padding-right: 0.5rem;
  }

  .tag-color-pick {
    width: 1.4rem; height: 1.4rem;
    border: none; border-radius: 50%;
    padding: 0; cursor: pointer;
    background: none; flex-shrink: 0;
  }

  .tag-edit-input {
    flex: 1;
    background: var(--bg-3);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 0.25rem 0.4rem;
    font-size: 0.78rem;
    color: var(--text-1);
    outline: none;
    min-width: 0;
  }
  .tag-edit-input:focus { border-color: var(--accent); }

  .btn-icon-xs {
    background: none;
    border: none;
    cursor: pointer;
    padding: 0.2rem;
    border-radius: 3px;
    display: flex;
    align-items: center;
    flex-shrink: 0;
  }
  .btn-save   { color: var(--accent); }
  .btn-save:hover   { background: var(--accent-bg); }
  .btn-save:disabled { opacity: 0.4; cursor: default; }
  .btn-cancel { color: var(--text-3); }
  .btn-cancel:hover { background: var(--surface-2); }

  /* Add tag popup */
  .section-label-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 0.5rem;
    margin-bottom: 0.15rem;
  }

  .popup-anchor {
    position: relative;
  }

  .btn-add-area {
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-2);
    padding: 0.1rem 0.2rem;
    border-radius: 3px;
    display: flex;
    align-items: center;
  }
  .btn-add-area:hover { color: var(--accent); background: var(--bg-3); }

  /* Modal overlay */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 200;
    backdrop-filter: blur(2px);
  }

  .tag-modal {
    background: var(--bg-2);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 1.25rem;
    box-shadow: var(--shadow-lg);
    width: 300px;
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
  }

  .tag-modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .tag-modal-title {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--text);
  }

  .popup-hint {
    font-size: 0.7rem;
    color: var(--text-3);
    line-height: 1.3;
    padding: 0 0.1rem;
  }
  .popup-hint code {
    background: var(--surface-2);
    border-radius: 3px;
    padding: 0.05rem 0.25rem;
    font-size: 0.68rem;
  }

  .popup-input {
    width: 100%;
    padding: 0.3rem 0.5rem;
    font-size: 0.82rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--text);
    outline: none;
    box-sizing: border-box;
  }
  .popup-input:focus { border-color: var(--accent); }

  .parent-select-row {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }

  .parent-select-label {
    font-size: 0.75rem;
    color: var(--text-3);
    flex-shrink: 0;
  }

  .parent-select {
    flex: 1;
    padding: 0.25rem 0.4rem;
    font-size: 0.78rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    color: var(--text);
    outline: none;
    cursor: pointer;
  }
  .parent-select:focus { border-color: var(--accent); }


  .suggestions {
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    overflow: hidden;
  }

  .sug-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.3rem 0.5rem;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 0.82rem;
    color: var(--text);
    text-align: left;
    transition: background 0.1s;
  }
  .sug-item:hover { background: var(--surface); }

  .sug-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }

  .color-row { display: flex; gap: 0.3rem; flex-wrap: wrap; }

  .color-swatch {
    width: 18px; height: 18px;
    border-radius: 50%;
    border: 2px solid transparent;
    cursor: pointer;
    padding: 0;
    transition: transform 0.1s;
  }
  .color-swatch.active { border-color: var(--text); transform: scale(1.2); }
  .color-swatch:hover  { transform: scale(1.15); }

  .color-swatch-custom {
    position: relative;
    background: conic-gradient(#f43f5e, #f97316, #eab308, #22c55e, #06b6d4, #6366f1, #ec4899, #f43f5e);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .color-swatch-custom input[type="color"] {
    position: absolute; inset: 0; width: 100%; height: 100%;
    opacity: 0; cursor: pointer; border: none; padding: 0; margin: 0;
  }

  .custom-dot {
    position: absolute; inset: 3px;
    border-radius: 50%;
    border: 1.5px solid rgba(255,255,255,0.7);
    pointer-events: none;
  }

  .create-btn {
    background: var(--accent);
    color: #fff;
    border: none;
    border-radius: var(--radius-sm);
    padding: 0.3rem 0.6rem;
    font-size: 0.78rem;
    cursor: pointer;
    text-align: left;
  }
  .create-btn:hover:not(:disabled) { background: var(--accent-hover); }
  .create-btn:disabled { opacity: 0.5; cursor: default; }

  /* Group add-child button */
  .group-add-row { padding-top: 0.05rem; padding-bottom: 0.1rem; }

  .btn-group-add {
    display: flex;
    align-items: center;
    gap: 0.25rem;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--text-3);
    font-size: 0.74rem;
    padding: 0.15rem 0.3rem;
    border-radius: 3px;
  }
  .btn-group-add:hover { color: var(--accent); background: var(--accent-bg); }

  .areas-empty {
    font-size: 0.75rem;
    color: var(--text-2);
    padding: 0.2rem 0.5rem;
    font-style: italic;
  }
</style>
