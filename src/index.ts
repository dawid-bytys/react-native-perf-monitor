import { installJsMetricsReporter } from './jsMetricsReporter';
import NativeRNPerfMonitor from './NativeRNPerfMonitor';

function show() {
  NativeRNPerfMonitor?.show();
}

function hide() {
  NativeRNPerfMonitor?.hide();
}

function toggle() {
  NativeRNPerfMonitor?.toggle();
}

function isVisible() {
  return NativeRNPerfMonitor?.isVisible() ?? false;
}

export const PerfMonitor = {
  show,
  hide,
  toggle,
  isVisible,
};

if (__DEV__ && NativeRNPerfMonitor) {
  installJsMetricsReporter(NativeRNPerfMonitor);
}
