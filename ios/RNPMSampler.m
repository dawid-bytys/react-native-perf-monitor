#import "RNPMSampler.h"

#import <ifaddrs.h>
#import <mach/mach.h>
#import <net/if.h>
#import <sys/resource.h>

static const NSTimeInterval RNPMSampleInterval = 0.5;
static const NSTimeInterval RNPMJsStallThreshold = 1.0;
static const NSUInteger RNPMViewCountSampleStride = 2;
static const NSUInteger RNPMSeriesCapacity = 60;
static const double RNPMDefaultJsTargetFps = 60;

static double RNPMReadCpuSeconds(void)
{
  struct rusage usage;

  if (getrusage(RUSAGE_SELF, &usage) != 0) {
    return 0;
  }

  double userSeconds = usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6;
  double systemSeconds = usage.ru_stime.tv_sec + usage.ru_stime.tv_usec / 1e6;

  return userSeconds + systemSeconds;
}

static double RNPMReadMemoryBytes(void)
{
  task_vm_info_data_t info;
  mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);

  return result == KERN_SUCCESS ? (double)info.phys_footprint : 0;
}

static void RNPMReadNetworkBytes(uint64_t *downBytes, uint64_t *upBytes)
{
  struct ifaddrs *addresses = NULL;

  *downBytes = 0;
  *upBytes = 0;

  if (getifaddrs(&addresses) != 0) {
    return;
  }

  for (struct ifaddrs *address = addresses; address != NULL; address = address->ifa_next) {
    BOOL isLinkLayer = address->ifa_addr != NULL && address->ifa_addr->sa_family == AF_LINK;
    BOOL isLoopback = (address->ifa_flags & IFF_LOOPBACK) != 0;

    if (!isLinkLayer || isLoopback || address->ifa_data == NULL) {
      continue;
    }

    const struct if_data *data = (const struct if_data *)address->ifa_data;

    *downBytes += data->ifi_ibytes;
    *upBytes += data->ifi_obytes;
  }

  freeifaddrs(addresses);
}

static double RNPMBytesPerSecond(uint64_t current, uint64_t previous, double elapsedSeconds)
{
  if (current < previous) {
    return 0;
  }

  return (current - previous) / elapsedSeconds;
}

static NSInteger RNPMCountViews(UIView *view)
{
  NSInteger count = 1;

  for (UIView *subview in view.subviews) {
    count += RNPMCountViews(subview);
  }

  return count;
}

static RNPMThermalState RNPMReadThermalState(void)
{
  switch ([NSProcessInfo processInfo].thermalState) {
    case NSProcessInfoThermalStateNominal:
      return RNPMThermalStateNominal;
    case NSProcessInfoThermalStateFair:
      return RNPMThermalStateFair;
    case NSProcessInfoThermalStateSerious:
      return RNPMThermalStateSerious;
    case NSProcessInfoThermalStateCritical:
      return RNPMThermalStateCritical;
  }

  return RNPMThermalStateUnknown;
}

@implementation RNPMSampler {
  CADisplayLink *_displayLink;
  NSTimer *_timer;
  CFTimeInterval _previousFrameTimestamp;
  NSUInteger _framesInWindow;
  NSInteger _droppedFramesInWindow;
  double _frameBudgetSeconds;
  CFTimeInterval _windowStart;
  double _cpuSecondsAtWindowStart;
  uint64_t _networkDownBytesAtWindowStart;
  uint64_t _networkUpBytesAtWindowStart;
  NSUInteger _sampleCount;
  NSInteger _viewCount;

  BOOL _hasJsReports;
  CFTimeInterval _lastJsReportTime;
  double _pendingJsFrames;
  double _pendingJsIntervalMs;
  double _pendingCommits;
  double _pendingRenderTotalMs;
  double _pendingRenderMaxMs;
  double _jsHeapUsedBytes;
  double _jsHeapTotalBytes;
  NSInteger _activeRequests;
  double _jsFps;
  double _jsTargetFps;
}

- (instancetype)init
{
  if (self = [super init]) {
    _uiFpsSeries = [[RNPMSeries alloc] initWithCapacity:RNPMSeriesCapacity];
    _jsFpsSeries = [[RNPMSeries alloc] initWithCapacity:RNPMSeriesCapacity];
    _cpuSeries = [[RNPMSeries alloc] initWithCapacity:RNPMSeriesCapacity];
    _memorySeries = [[RNPMSeries alloc] initWithCapacity:RNPMSeriesCapacity];
    _renderSeries = [[RNPMSeries alloc] initWithCapacity:RNPMSeriesCapacity];
    _frameBudgetSeconds = 1.0 / 60;
    _jsTargetFps = RNPMDefaultJsTargetFps;
    _jsHeapUsedBytes = -1;
    _jsHeapTotalBytes = -1;
  }

  return self;
}

- (void)start
{
  if (_displayLink != nil) {
    return;
  }

  [self resetWindow];

  NSInteger maximumFps = [UIScreen mainScreen].maximumFramesPerSecond;

  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleFrame:)];
  _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(maximumFps, maximumFps, maximumFps);
  [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

  _timer = [NSTimer timerWithTimeInterval:RNPMSampleInterval
                                   target:self
                                 selector:@selector(sample)
                                 userInfo:nil
                                  repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)stop
{
  [_displayLink invalidate];
  [_timer invalidate];
  _displayLink = nil;
  _timer = nil;
}

- (void)recordJsReport:(RNPMJsReport)report
{
  _hasJsReports = YES;
  _lastJsReportTime = CACurrentMediaTime();
  _pendingJsFrames += report.frames;
  _pendingJsIntervalMs += report.intervalMs;
  _pendingCommits += report.commits;
  _pendingRenderTotalMs += report.renderTotalMs;
  _pendingRenderMaxMs = MAX(_pendingRenderMaxMs, report.renderMaxMs);
  _jsHeapUsedBytes = report.heapUsedBytes;
  _jsHeapTotalBytes = report.heapTotalBytes;
  _activeRequests = (NSInteger)report.activeRequests;
}

- (void)resetWindow
{
  _windowStart = CACurrentMediaTime();
  _previousFrameTimestamp = 0;
  _framesInWindow = 0;
  _droppedFramesInWindow = 0;
  _cpuSecondsAtWindowStart = RNPMReadCpuSeconds();
  RNPMReadNetworkBytes(&_networkDownBytesAtWindowStart, &_networkUpBytesAtWindowStart);
}

- (void)handleFrame:(CADisplayLink *)displayLink
{
  if (_previousFrameTimestamp > 0) {
    double gapSeconds = displayLink.timestamp - _previousFrameTimestamp;
    double budgetSeconds = displayLink.targetTimestamp - displayLink.timestamp;

    if (budgetSeconds > 0) {
      _frameBudgetSeconds = budgetSeconds;
      _droppedFramesInWindow += MAX(lround(gapSeconds / budgetSeconds) - 1, 0);
    }
  }

  _previousFrameTimestamp = displayLink.timestamp;
  _framesInWindow += 1;
}

- (void)sample
{
  CFTimeInterval now = CACurrentMediaTime();
  double elapsedSeconds = MAX(now - _windowStart, 0.001);
  RNPMSnapshot snapshot = {0};

  [self fillFrameMetrics:&snapshot elapsedSeconds:elapsedSeconds];
  [self fillSystemMetrics:&snapshot elapsedSeconds:elapsedSeconds];
  [self fillJsMetrics:&snapshot elapsedSeconds:elapsedSeconds now:now];
  [self recordSeriesForSnapshot:snapshot];

  _latestSnapshot = snapshot;
  _sampleCount += 1;
  _windowStart = now;
  _framesInWindow = 0;
  _droppedFramesInWindow = 0;

  [self.delegate sampler:self didProduceSnapshot:snapshot];
}

- (void)fillFrameMetrics:(RNPMSnapshot *)snapshot elapsedSeconds:(double)elapsedSeconds
{
  snapshot->displayHz = round(1.0 / _frameBudgetSeconds);
  snapshot->uiFps = MIN(_framesInWindow / elapsedSeconds, snapshot->displayHz);
  snapshot->droppedFrames = _droppedFramesInWindow;
}

- (void)fillSystemMetrics:(RNPMSnapshot *)snapshot elapsedSeconds:(double)elapsedSeconds
{
  double cpuSeconds = RNPMReadCpuSeconds();
  uint64_t networkDownBytes = 0;
  uint64_t networkUpBytes = 0;

  RNPMReadNetworkBytes(&networkDownBytes, &networkUpBytes);

  if (_sampleCount % RNPMViewCountSampleStride == 0) {
    _viewCount = [self countVisibleViews];
  }

  snapshot->cpuPercent = MAX((cpuSeconds - _cpuSecondsAtWindowStart) / elapsedSeconds * 100, 0);
  snapshot->cpuCores = [NSProcessInfo processInfo].activeProcessorCount;
  snapshot->memoryBytes = RNPMReadMemoryBytes();
  snapshot->viewCount = _viewCount;
  snapshot->networkDownBytesPerSecond =
      RNPMBytesPerSecond(networkDownBytes, _networkDownBytesAtWindowStart, elapsedSeconds);
  snapshot->networkUpBytesPerSecond = RNPMBytesPerSecond(networkUpBytes, _networkUpBytesAtWindowStart, elapsedSeconds);
  snapshot->thermalState = RNPMReadThermalState();

  _cpuSecondsAtWindowStart = cpuSeconds;
  _networkDownBytesAtWindowStart = networkDownBytes;
  _networkUpBytesAtWindowStart = networkUpBytes;
}

- (void)fillJsMetrics:(RNPMSnapshot *)snapshot elapsedSeconds:(double)elapsedSeconds now:(CFTimeInterval)now
{
  snapshot->hasJsMetrics = _hasJsReports;
  snapshot->jsHeapUsedBytes = _jsHeapUsedBytes;
  snapshot->jsHeapTotalBytes = _jsHeapTotalBytes;
  snapshot->activeRequests = _activeRequests;

  if (!_hasJsReports) {
    return;
  }

  BOOL isStalled = now - _lastJsReportTime > RNPMJsStallThreshold;

  if (_pendingJsIntervalMs > 0) {
    _jsFps = _pendingJsFrames / _pendingJsIntervalMs * 1000;
  } else if (isStalled) {
    _jsFps = 0;
  }

  if (_jsFps > RNPMDefaultJsTargetFps * 1.1) {
    _jsTargetFps = MAX(_jsTargetFps, round(1.0 / _frameBudgetSeconds));
  }

  snapshot->isJsStalled = isStalled;
  snapshot->jsFps = MIN(_jsFps, _jsTargetFps);
  snapshot->jsTargetFps = _jsTargetFps;
  snapshot->reactCommitsPerSecond = _pendingCommits / elapsedSeconds;
  snapshot->reactRenderAvgMs = _pendingCommits > 0 ? _pendingRenderTotalMs / _pendingCommits : 0;
  snapshot->reactRenderMaxMs = _pendingRenderMaxMs;

  _pendingJsFrames = 0;
  _pendingJsIntervalMs = 0;
  _pendingCommits = 0;
  _pendingRenderTotalMs = 0;
  _pendingRenderMaxMs = 0;
}

- (void)recordSeriesForSnapshot:(RNPMSnapshot)snapshot
{
  [_uiFpsSeries push:snapshot.uiFps];
  [_cpuSeries push:snapshot.cpuPercent];
  [_memorySeries push:snapshot.memoryBytes];

  if (snapshot.hasJsMetrics) {
    [_jsFpsSeries push:snapshot.jsFps];
    [_renderSeries push:snapshot.reactRenderMaxMs];
  }
}

- (NSInteger)countVisibleViews
{
  NSInteger count = 0;

  for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
      continue;
    }

    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
      if (window.hidden || window == self.excludedWindow) {
        continue;
      }

      count += RNPMCountViews(window);
    }
  }

  return count;
}

@end
