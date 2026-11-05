interface HermesInstrumentedStats {
  js_allocatedBytes?: number;
  js_heapSize?: number;
}

interface HermesInternalApi {
  getInstrumentedStats?: () => HermesInstrumentedStats;
}

const UNAVAILABLE = -1;

export function readJsHeap() {
  const globalWithHermes = globalThis as {
    HermesInternal?: HermesInternalApi;
  };
  const stats = globalWithHermes.HermesInternal?.getInstrumentedStats?.();

  return {
    heapUsedBytes: stats?.js_allocatedBytes ?? UNAVAILABLE,
    heapTotalBytes: stats?.js_heapSize ?? UNAVAILABLE,
  };
}
