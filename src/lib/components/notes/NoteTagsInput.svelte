<script lang="ts">
  import type { NoteTag, NoteTagInfo } from '$lib/types';
  import { t } from '$lib/i18n';

  interface Props {
    selectedTags: NoteTagInfo[];
    allTags: NoteTag[];
    onchange: (tagNames: string[]) => void;
  }

  let { selectedTags, allTags, onchange }: Props = $props();

  let inputValue = $state('');
  let showDropdown = $state(false);
  let inputEl: HTMLInputElement | null = $state(null);

  const selectedNames = $derived(new Set(selectedTags.map((t) => t.name)));

  const suggestions = $derived(
    allTags
      .filter((t) => !selectedNames.has(t.name) && t.name.toLowerCase().includes(inputValue.toLowerCase()))
      .slice(0, 8)
  );

  function addTag(name: string) {
    const trimmed = name.trim();
    if (!trimmed || selectedNames.has(trimmed)) return;
    onchange([...selectedNames, trimmed]);
    inputValue = '';
    showDropdown = false;
  }

  function removeTag(name: string) {
    onchange([...selectedNames].filter((n) => n !== name));
  }

  function onKeydown(e: KeyboardEvent) {
    if ((e.key === 'Enter' || e.key === ',') && inputValue.trim()) {
      e.preventDefault();
      addTag(inputValue);
    }
    if (e.key === 'Backspace' && !inputValue && selectedTags.length > 0) {
      removeTag(selectedTags[selectedTags.length - 1].name);
    }
    if (e.key === 'Escape') showDropdown = false;
  }

  function onInput() {
    showDropdown = inputValue.length > 0;
  }

  function onBlur() {
    // Delay to allow click on suggestion
    setTimeout(() => { showDropdown = false; }, 150);
  }
</script>

<div class="tags-input-wrap">
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="tags-field" onclick={() => inputEl?.focus()}>
    {#each selectedTags as tag (tag.id)}
      <span class="tag-chip" style="border-color: {tag.color}; color: {tag.color}; background: {tag.color}18">
        {tag.name}
        <button class="chip-remove" onclick={(e) => { e.stopPropagation(); removeTag(tag.name); }}>×</button>
      </span>
    {/each}
    <input
      bind:this={inputEl}
      bind:value={inputValue}
      type="text"
      placeholder={selectedTags.length === 0 ? $t('notes_tags_placeholder') : ''}
      class="tag-input"
      onkeydown={onKeydown}
      oninput={onInput}
      onblur={onBlur}
      onfocus={() => { if (inputValue) showDropdown = true; }}
    />
  </div>

  {#if showDropdown && suggestions.length > 0}
    <div class="suggestions">
      {#each suggestions as s (s.id)}
        <button
          class="suggestion-item"
          onmousedown={(e) => { e.preventDefault(); addTag(s.name); }}
        >
          <span class="sug-dot" style="background:{s.color}"></span>
          {s.name}
        </button>
      {/each}
      {#if inputValue.trim() && !allTags.some((t) => t.name === inputValue.trim())}
        <button class="suggestion-item new-tag" onmousedown={(e) => { e.preventDefault(); addTag(inputValue); }}>
        {@html $t('notes_tags_create', { name: inputValue.trim() }).replace(inputValue.trim(), `<strong>${inputValue.trim()}</strong>`)}
        </button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .tags-input-wrap {
    position: relative;
  }

  .tags-field {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.3rem;
    padding: 0.35rem 0.5rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    cursor: text;
    min-height: 34px;
  }

  .tags-field:focus-within {
    border-color: var(--accent);
  }

  .tag-chip {
    display: inline-flex;
    align-items: center;
    gap: 0.2rem;
    font-size: 0.73rem;
    padding: 0.15rem 0.45rem;
    border-radius: 999px;
    border: 1px solid;
    font-weight: 500;
    white-space: nowrap;
  }

  .chip-remove {
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
    font-size: 0.85rem;
    line-height: 1;
    color: inherit;
    opacity: 0.7;
    display: flex;
    align-items: center;
  }

  .chip-remove:hover { opacity: 1; }

  .tag-input {
    flex: 1;
    min-width: 80px;
    background: none;
    border: none;
    outline: none;
    color: var(--text);
    font-size: 0.83rem;
    padding: 0;
  }

  .suggestions {
    position: absolute;
    top: calc(100% + 4px);
    left: 0;
    right: 0;
    background: var(--bg-2);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    box-shadow: var(--shadow-lg);
    z-index: 100;
    overflow: hidden;
  }

  .suggestion-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0.45rem 0.75rem;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 0.83rem;
    color: var(--text);
    text-align: left;
    transition: background 0.1s;
  }

  .suggestion-item:hover { background: var(--surface); }

  .new-tag { color: var(--accent); }

  .sug-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
</style>
