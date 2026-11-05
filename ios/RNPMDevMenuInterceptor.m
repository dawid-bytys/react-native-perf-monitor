#import <React/RCTBridgeModule.h>
#import <React/RCTDefines.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "RNPMConfiguration.h"
#import "RNPMOverlayController.h"

static void RNPMReplaceInstanceMethod(Class targetClass, SEL selector, id block)
{
  Method method = class_getInstanceMethod(targetClass, selector);

  if (method == NULL) {
    return;
  }

  class_replaceMethod(targetClass, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method));
}

static void RNPMCaptureDevSettings(id<RCTBridgeModule> perfMonitor)
{
  if (![perfMonitor respondsToSelector:@selector(moduleRegistry)]) {
    return;
  }

  [RNPMOverlayController sharedController].devSettings = [perfMonitor.moduleRegistry moduleForName:"DevSettings"];
}

@interface RNPMDevMenuInterceptor : NSObject
@end

@implementation RNPMDevMenuInterceptor

+ (void)load
{
#if RCT_DEV
  [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                    object:nil
                                                     queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(NSNotification *notification) {
                                                  [RNPMDevMenuInterceptor interceptPerfMonitor];
                                                  [[RNPMOverlayController sharedController] restoreVisibilityOnLaunch];
                                                }];
#endif
}

+ (void)interceptPerfMonitor
{
  Class perfMonitorClass = NSClassFromString(@"RCTPerfMonitor");

  if (!RNPMConfigurationReplacesDevMenu() || perfMonitorClass == nil) {
    return;
  }

  RNPMReplaceInstanceMethod(perfMonitorClass, NSSelectorFromString(@"show"), ^(id<RCTBridgeModule> perfMonitor) {
    RNPMCaptureDevSettings(perfMonitor);
    [[RNPMOverlayController sharedController] showFromDevMenu];
  });
  RNPMReplaceInstanceMethod(perfMonitorClass, NSSelectorFromString(@"hide"), ^(id<RCTBridgeModule> perfMonitor) {
    RNPMCaptureDevSettings(perfMonitor);
    [[RNPMOverlayController sharedController] hideFromDevMenu];
  });
  RNPMReplaceInstanceMethod(perfMonitorClass, NSSelectorFromString(@"invalidate"), ^(id perfMonitor){
  });
  [self interceptDevMenuItemOfClass:perfMonitorClass];
}

+ (void)interceptDevMenuItemOfClass:(Class)perfMonitorClass
{
  SEL devMenuItemSelector = NSSelectorFromString(@"devMenuItem");
  Method devMenuItemMethod = class_getInstanceMethod(perfMonitorClass, devMenuItemSelector);

  if (devMenuItemMethod == NULL) {
    return;
  }

  id (*originalDevMenuItem)(id, SEL) = (id(*)(id, SEL))method_getImplementation(devMenuItemMethod);

  RNPMReplaceInstanceMethod(perfMonitorClass, devMenuItemSelector, ^id(id<RCTBridgeModule> perfMonitor) {
    RNPMCaptureDevSettings(perfMonitor);

    return originalDevMenuItem(perfMonitor, devMenuItemSelector);
  });
}

@end
