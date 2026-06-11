export function portal(node: HTMLElement) {
  document.body.appendChild(node);
  return {
    destroy() {
      if (document.body.contains(node)) {
        document.body.removeChild(node);
      }
    },
  };
}
