#import "RNPerfMonitor.h"

#import <React/RCTDefines.h>

#import "RNPMOverlayController.h"

@implementation RNPerfMonitor

@synthesize moduleRegistry = _moduleRegistry;

RCT_EXPORT_MODULE()

- (instancetype)init
{
  if (self = [super init]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleVisibilityChange:)
                                                 name:RNPMVisibilityDidChangeNotification
                                               object:nil];
  }

  return self;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)handleVisibilityChange:(NSNotification *)notification
{
  [self emitOnVisibilityChange:[notification.userInfo[RNPMVisibilityKey] boolValue]];
}

- (RNPMOverlayController *)controllerWithDevSettings
{
  RNPMOverlayController *controller = [RNPMOverlayController sharedController];

  controller.devSettings = [_moduleRegistry moduleForName:"DevSettings"];

  return controller;
}

- (void)show
{
#if RCT_DEV
  [[self controllerWithDevSettings] show];
#endif
}

- (void)hide
{
#if RCT_DEV
  [[self controllerWithDevSettings] hide];
#endif
}

- (void)toggle
{
#if RCT_DEV
  [[self controllerWithDevSettings] toggle];
#endif
}

- (NSNumber *)isVisible
{
  return @([RNPMOverlayController sharedController].isVisible);
}

- (void)reportJsMetrics:(JS::NativeRNPerfMonitor::JsMetricsReport &)report
{
  RNPMJsReport jsReport = {
      .frames = report.frames(),
      .intervalMs = report.intervalMs(),
      .commits = report.commits(),
      .renderTotalMs = report.renderTotalMs(),
      .renderMaxMs = report.renderMaxMs(),
      .heapUsedBytes = report.heapUsedBytes(),
      .heapTotalBytes = report.heapTotalBytes(),
      .activeRequests = report.activeRequests(),
  };

  [[RNPMOverlayController sharedController] recordJsReport:jsReport];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
#if RCT_DEV
  dispatch_async(dispatch_get_main_queue(), ^{
    [RNPMOverlayController sharedController].devSettings = [self->_moduleRegistry moduleForName:"DevSettings"];
  });
#endif

  return std::make_shared<facebook::react::NativeRNPerfMonitorSpecJSI>(params);
}

@end
