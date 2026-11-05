import PerfMonitor from './NativePerfMonitor';

export function multiply(a: number, b: number): number {
  return PerfMonitor.multiply(a, b);
}
