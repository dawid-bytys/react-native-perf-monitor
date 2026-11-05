type Fetch = typeof globalThis.fetch;

interface PolyfilledFetch extends Fetch {
  polyfill?: boolean;
}

function patchXMLHttpRequest(
  onRequestStart: () => void,
  onRequestEnd: () => void
) {
  const prototype = globalThis.XMLHttpRequest?.prototype;

  if (!prototype) {
    return () => {};
  }

  const originalSend = prototype.send;
  const trackedRequests = new WeakSet<XMLHttpRequest>();

  const send: XMLHttpRequest['send'] = function (this: XMLHttpRequest, body) {
    onRequestStart();

    if (!trackedRequests.has(this)) {
      trackedRequests.add(this);
      this.addEventListener('loadend', onRequestEnd);
    }

    return originalSend.call(this, body);
  };

  prototype.send = send;

  return () => {
    if (prototype.send === send) {
      prototype.send = originalSend;
    }
  };
}

interface ReadableResponse {
  body?: unknown;
  arrayBuffer?: unknown;
  blob?: unknown;
  bytes?: unknown;
  formData?: unknown;
  json?: unknown;
  text?: unknown;
}

type BodyReaderName = Exclude<keyof ReadableResponse, 'body'>;

const BODY_READERS: BodyReaderName[] = [
  'arrayBuffer',
  'blob',
  'bytes',
  'formData',
  'json',
  'text',
];

function endAfterBodyIsRead(
  response: ReadableResponse,
  onRequestEnd: () => void
) {
  let hasEnded = false;

  function end() {
    if (hasEnded) {
      return;
    }

    hasEnded = true;
    onRequestEnd();
  }

  if (!response.body) {
    end();
    return;
  }

  BODY_READERS.forEach((readerName) => {
    const reader = response[readerName];

    if (typeof reader !== 'function') {
      return;
    }

    Object.assign(response, {
      [readerName]: (...args: unknown[]) =>
        Promise.resolve(Reflect.apply(reader, response, args)).finally(end),
    });
  });
}

function patchNativeFetch(
  onRequestStart: () => void,
  onRequestEnd: () => void
) {
  const originalFetch: PolyfilledFetch | undefined = globalThis.fetch;

  if (!originalFetch || originalFetch.polyfill) {
    return () => {};
  }

  const fetch: Fetch = async (input, init) => {
    onRequestStart();

    try {
      const response = await originalFetch(input, init);

      endAfterBodyIsRead(response, onRequestEnd);

      return response;
    } catch (error) {
      onRequestEnd();
      throw error;
    }
  };

  globalThis.fetch = fetch;

  return () => {
    if (globalThis.fetch === fetch) {
      globalThis.fetch = originalFetch;
    }
  };
}

export function startNetworkProbe() {
  let activeRequests = 0;
  let isStopped = false;

  function handleRequestStart() {
    activeRequests += 1;
  }

  function handleRequestEnd() {
    if (isStopped) {
      return;
    }

    activeRequests = Math.max(activeRequests - 1, 0);
  }

  const restoreXMLHttpRequest = patchXMLHttpRequest(
    handleRequestStart,
    handleRequestEnd
  );
  const restoreFetch = patchNativeFetch(handleRequestStart, handleRequestEnd);

  function stop() {
    isStopped = true;
    restoreXMLHttpRequest();
    restoreFetch();
  }

  return {
    getActiveRequests: () => activeRequests,
    stop,
  };
}
