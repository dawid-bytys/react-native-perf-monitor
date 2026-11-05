interface FiberRoot {
  current?: {
    actualDuration?: number;
  };
}

type CommitHandler = (
  rendererId: number,
  root: FiberRoot,
  ...rest: unknown[]
) => unknown;

interface DevToolsHook {
  onCommitFiberRoot?: CommitHandler;
}

export interface ReactCommitStats {
  commits: number;
  renderTotalMs: number;
  renderMaxMs: number;
}

function getDevToolsHook() {
  const globalWithHook = globalThis as {
    __REACT_DEVTOOLS_GLOBAL_HOOK__?: DevToolsHook;
  };

  return globalWithHook.__REACT_DEVTOOLS_GLOBAL_HOOK__;
}

function createEmptyStats(): ReactCommitStats {
  return {
    commits: 0,
    renderTotalMs: 0,
    renderMaxMs: 0,
  };
}

export function startReactCommitProbe() {
  const hook = getDevToolsHook();
  let stats = createEmptyStats();

  function flush() {
    const flushedStats = stats;

    stats = createEmptyStats();

    return flushedStats;
  }

  if (!hook) {
    return {
      flush,
      stop: () => {},
    };
  }

  const originalOnCommitFiberRoot = hook.onCommitFiberRoot;

  const onCommitFiberRoot: CommitHandler = function (
    this: DevToolsHook,
    rendererId,
    root,
    ...rest
  ) {
    const renderMs = root.current?.actualDuration ?? 0;

    stats.commits += 1;
    stats.renderTotalMs += renderMs;
    stats.renderMaxMs = Math.max(stats.renderMaxMs, renderMs);

    return originalOnCommitFiberRoot?.call(this, rendererId, root, ...rest);
  };

  hook.onCommitFiberRoot = onCommitFiberRoot;

  function stop() {
    if (hook?.onCommitFiberRoot === onCommitFiberRoot) {
      hook.onCommitFiberRoot = originalOnCommitFiberRoot;
    }
  }

  return {
    flush,
    stop,
  };
}
