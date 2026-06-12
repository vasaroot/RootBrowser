<script lang="ts">
  import type { NoteTag, NoteTagInfo } from '$lib/types';
  import { api } from '$lib/api';
  import Icon from '$lib/Icon.svelte';
  import { t } from '$lib/i18n';

  interface Props {
    selectedTags: NoteTagInfo[];
    allTags: NoteTag[];
    onchange: (tagNames: string[]) => void;
  }

  let { selectedTags, allTags, onchange }: Props = $props();

  const TAG_COLORS = [
    '#6366f1', '#3b82f6', '#06b6d4', '#10b981',
    '#f59e0b', '#ef4444', '#ec4899', '#8b5cf6',
  ];

  let open = $state(false);
  let inputValue = $state('');
  let selectedColor = $state(TAG_COLORS[0]);
  let inputEl: HTMLInputElement | null = $state(null);
  let wrapEl: HTMLDivElement | null = $state(null);

  const selectedNames = $derived(new Set(selectedTags.map((t) => t.name)));

  const suggestions = $derived(
    allTags
      .filter((t) => !selectedNames.has(t.name) && t.name.toLowerCase().includes(inputValue.toLowerCase()))
      .slice(0, 6)
  );

  const isNew = $derived(
    inputValue.trim().length > 0 && !allTags.some((t) => t.name === inputValue.trim())
  );

  function openPopup() {
    open = true;
    inputValue = '';
    selectedColor = TAG_COLORS[0];
    setTimeout(() => inputEl?.focus(), 50);
  }

  function close() {
    open = false;
    inputValue = '';
  }

  async function addTag(name: string, color?: string) {
    const trimmed = name.trim();
    if (!trimmed || selectedNames.has(trimmed)) { close(); return; }

    const existing = allTags.find((t) => t.name === trimmed);
    if (!existing && color) {
      await api.notes.tagCreate(trimmed, color);
    }

    onchange([...selectedNames, trimmed]);
    close();
  }

  function removeTag(name: string) {
    onchange([...selectedNames].filter((n) => n !== name));
  }

  function onKeydown(e: KeyboardEvent) {
    if ((e.key === 'Enter' || e.key === ',') && inputValue.trim()) {
      e.preventDefault();
      void addTag(inputValue, selectedColor);
    }
    if (e.key === 'Escape') close();
  }

  function onOutsideClick(e: MouseEvent) {
    if (wrapEl && !wrapEl.contains(e.target as Node)) close();
  }
</script>

<svelte:window onclick={onOutsideClick} />

<div class="tags-wrap" bind:this={wrapEl}>
  {#each selectedTags as tag (tag.id)}
    <span class="chip" style="border-color:{tag.color};color:{tag.color};background:{tag.color}18">
      {tag.name}
      <button class="chip-x" onclick={() => removeTag(tag.name)}>×</button>
    </span>
  {/each}

  <div class="add-wrap">
    <button class="add-btn" onclick={openPopup} title={$t('notes_tags_add')}>
      <Icon name="plus" size={12} />
    </button>

    {#if open}
      <div class="popup">
        <input
          bind:this={inputEl}
          bind:value={inputValue}
          type="text"
          class="popup-input"
          placeholder={$t('notes_tags_placeholder')}
          onkeydown={onKeydown}
        />

        {#if suggestions.length > 0}
          <div class="suggestions">
            {#each suggestions as s (s.id)}
              <button class="sug-item" onmousedown={(e) => { e.preventDefault(); void addTag(s.name); }}>
                <span class="sug-dot" style="background:{s.color}"></span>
                {s.name}
              </button>
            {/each}
          </div>
        {/if}

        {#if isNew}
          <div class="color-row">
            {#each TAG_COLORS as c}
              <button
                class="color-swatch"
                class:active={selectedColor === c}
                style="background:{c}"
                onclick={() => (selectedColor = c)}
              ></button>
            {/each}
            <label
              class="color-swatch color-swatch-custom"
              class:active={!TAG_COLORS.includes(selectedColor)}
              title="Custom color"
            >
              <input type="color" bind:value={selectedColor} />
              {#if !TAG_COLORS.includes(selectedColor)}
                <span class="custom-dot" style="background:{selectedColor}"></span>
              {/if}
            </label>
          </div>
          <button class="create-btn" onclick={() => addTag(inputValue, selectedColor)}>
            {$t('notes_tags_create', { name: inputValue.trim() })}
          </button>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .tags-wrap {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 0.3rem;
    flex: 1;
    min-width: 0;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;
    font-size: 0.72rem;
    padding: 0.1rem 0.4rem;
    border-radius: 999px;
    border: 1px solid;
    font-weight: 500;
    white-space: nowrap;
  }

  .chip-x {
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
    font-size: 0.85rem;
    line-height: 1;
    color: inherit;
    opacity: 0.6;
    display: flex;
    align-items: center;
  }
  .chip-x:hover { opacity: 1; }

  .add-wrap {
    position: relative;
  }

  .add-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: none;
    border: 1px solid var(--border-2);
    color: var(--text-2);
    cursor: pointer;
    padding: 0;
    transition: all 0.15s;
  }
  .add-btn:hover { border-color: var(--accent); color: var(--accent); }

  .popup {
    position: absolute;
    top: calc(100% + 6px);
    left: 0;
    min-width: 200px;
    background: var(--bg-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    box-shadow: var(--shadow-lg);
    z-index: 500;
    padding: 0.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
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
  }
  .popup-input:focus { border-color: var(--accent); }

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

  .sug-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .color-row {
    display: flex;
    gap: 0.3rem;
    flex-wrap: wrap;
  }

  .color-swatch {
    width: 18px;
    height: 18px;
    border-radius: 50%;
    border: 2px solid transparent;
    cursor: pointer;
    padding: 0;
    transition: transform 0.1s;
  }
  .color-swatch.active { border-color: var(--text); transform: scale(1.2); }
  .color-swatch:hover { transform: scale(1.15); }

  .color-swatch-custom {
    position: relative;
    background: conic-gradient(#f43f5e, #f97316, #eab308, #22c55e, #06b6d4, #6366f1, #ec4899, #f43f5e);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .color-swatch-custom input[type="color"] {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    opacity: 0;
    cursor: pointer;
    border: none;
    padding: 0;
    margin: 0;
  }

  .custom-dot {
    position: absolute;
    inset: 3px;
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
    transition: background 0.15s;
  }
  .create-btn:hover { background: var(--accent-hover); }
</style>
