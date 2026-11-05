const OBJECTS_PER_MEGABYTE = 16_384;

export function allocateJsHeap(megabytes: number) {
  return Array.from(
    {
      length: megabytes * OBJECTS_PER_MEGABYTE,
    },
    (_, index) => ({
      index,
      label: `item-${index}`,
    })
  );
}
