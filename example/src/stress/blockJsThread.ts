export function blockJsThread(durationMs: number) {
  const end = Date.now() + durationMs;

  while (Date.now() < end) {}
}
