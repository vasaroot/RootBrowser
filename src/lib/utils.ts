import type { AppError } from '$lib/types';

export function formatError(e: unknown): string {
  if (e != null && typeof e === 'object' && 'message' in e) {
    return (e as AppError).message;
  }
  return String(e);
}
