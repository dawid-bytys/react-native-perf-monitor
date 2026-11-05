import { TurboModuleRegistry } from 'react-native';
import type { CodegenTypes, TurboModule } from 'react-native';

export interface JsMetricsReport {
  frames: number;
  intervalMs: number;
  commits: number;
  renderTotalMs: number;
  renderMaxMs: number;
  heapUsedBytes: number;
  heapTotalBytes: number;
  activeRequests: number;
}

export interface Spec extends TurboModule {
  show(): void;
  hide(): void;
  toggle(): void;
  isVisible(): boolean;
  reportJsMetrics(report: JsMetricsReport): void;
  readonly onVisibilityChange: CodegenTypes.EventEmitter<boolean>;
}

export default TurboModuleRegistry.get<Spec>('RNPerfMonitor');
