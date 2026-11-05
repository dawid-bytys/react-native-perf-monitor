import { startNetworkProbe } from './probes/networkProbe';
import { startReactCommitProbe } from './probes/reactCommitProbe';
import { readJsHeap } from './probes/readJsHeap';

import type { Spec } from './NativeRNPerfMonitor';

const REPORT_INTERVAL_MS = 500;

function startReporting(nativeModule: Spec) {
  const reactCommitProbe = startReactCommitProbe();
  const networkProbe = startNetworkProbe();
  let frames = 0;
  let windowStart = Date.now();
  let frameRequestId = requestAnimationFrame(handleFrame);

  function report(intervalMs: number) {
    nativeModule.reportJsMetrics({
      frames,
      intervalMs,
      ...reactCommitProbe.flush(),
      ...readJsHeap(),
      activeRequests: networkProbe.getActiveRequests(),
    });
  }

  function handleFrame() {
    const now = Date.now();
    const elapsedMs = now - windowStart;

    frames += 1;

    if (elapsedMs >= REPORT_INTERVAL_MS) {
      report(elapsedMs);
      frames = 0;
      windowStart = now;
    }

    frameRequestId = requestAnimationFrame(handleFrame);
  }

  return () => {
    cancelAnimationFrame(frameRequestId);
    reactCommitProbe.stop();
    networkProbe.stop();
  };
}

export function installJsMetricsReporter(nativeModule: Spec) {
  let stopReporting: (() => void) | null = null;

  function handleVisibilityChange(isVisible: boolean) {
    if (isVisible && !stopReporting) {
      stopReporting = startReporting(nativeModule);
      return;
    }

    if (!isVisible && stopReporting) {
      stopReporting();
      stopReporting = null;
    }
  }

  nativeModule.onVisibilityChange(handleVisibilityChange);
  handleVisibilityChange(nativeModule.isVisible());
}
