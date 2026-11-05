#import "RNPMOverlayController.h"

#import <UIKit/UIKit.h>

#import "RNPMConfiguration.h"
#import "RNPMOverlayWindow.h"
#import "RNPMPanelView.h"
#import "RNPMSampler.h"

NSNotificationName const RNPMVisibilityDidChangeNotification = @"RNPMVisibilityDidChangeNotification";
NSString *const RNPMVisibilityKey = @"visible";

static NSString *const RNPMPanelOriginKey = @"RNPerfMonitorPanelOrigin";
static NSString *const RNPMPanelExpandedKey = @"RNPerfMonitorPanelExpanded";
static const CGFloat RNPMScreenMargin = 6;

@protocol RNPMDevSettings <NSObject>

- (void)setIsPerfMonitorShown:(BOOL)isPerfMonitorShown;

@end

@interface RNPMOverlayController () <RNPMSamplerDelegate>
@end

@implementation RNPMOverlayController {
  RNPMSampler *_sampler;
  RNPMOverlayWindow *_window;
  RNPMPanelView *_panel;
  CGPoint _panGestureStartOrigin;
}

@synthesize visible = _visible;
@synthesize devSettings = _devSettings;

+ (instancetype)sharedController
{
  static RNPMOverlayController *sharedController;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedController = [RNPMOverlayController new];
  });

  return sharedController;
}

- (instancetype)init
{
  if (self = [super init]) {
    _sampler = [RNPMSampler new];
    _sampler.delegate = self;
    [self observeApplicationLifecycle];
  }

  return self;
}

- (void)observeApplicationLifecycle
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  [center addObserver:self selector:@selector(attachIfPossible) name:UISceneDidActivateNotification object:nil];
  [center addObserver:self
             selector:@selector(attachIfPossible)
                 name:UIApplicationDidBecomeActiveNotification
               object:nil];
  [center addObserver:self
             selector:@selector(pauseSampling)
                 name:UIApplicationDidEnterBackgroundNotification
               object:nil];
  [center addObserver:self
             selector:@selector(resumeSampling)
                 name:UIApplicationWillEnterForegroundNotification
               object:nil];
}

#pragma mark - Visibility

- (void)show
{
  [self setVisible:YES syncDevSettings:YES];
}

- (void)hide
{
  [self setVisible:NO syncDevSettings:YES];
}

- (void)toggle
{
  [self setVisible:!self.isVisible syncDevSettings:YES];
}

- (void)showFromDevMenu
{
  [self setVisible:YES syncDevSettings:NO];
}

- (void)hideFromDevMenu
{
  [self setVisible:NO syncDevSettings:NO];
}

- (void)restoreVisibilityOnLaunch
{
  BOOL shouldRestoreDevMenuState = RNPMConfigurationReplacesDevMenu() && RNPMConfigurationWasShownByDevMenu();

  if (RNPMConfigurationShowsOnLaunch() || shouldRestoreDevMenuState) {
    [self setVisible:YES syncDevSettings:NO];
  }
}

- (void)setVisible:(BOOL)visible syncDevSettings:(BOOL)shouldSyncDevSettings
{
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self setVisible:visible syncDevSettings:shouldSyncDevSettings];
    });
    return;
  }

  if (_visible == visible) {
    return;
  }

  _visible = visible;

  if (shouldSyncDevSettings) {
    [self syncDevSettings];
  }

  if (visible) {
    [self attachIfPossible];
  } else {
    [self detach];
  }

  [[NSNotificationCenter defaultCenter] postNotificationName:RNPMVisibilityDidChangeNotification
                                                      object:self
                                                    userInfo:@{RNPMVisibilityKey : @(visible)}];
}

- (void)setDevSettings:(id)devSettings
{
  if (_devSettings == devSettings) {
    return;
  }

  _devSettings = devSettings;
  [self syncDevSettings];
}

- (void)syncDevSettings
{
  id devSettings = self.devSettings;

  if (!RNPMConfigurationReplacesDevMenu() || ![devSettings respondsToSelector:@selector(setIsPerfMonitorShown:)]) {
    return;
  }

  [(id<RNPMDevSettings>)devSettings setIsPerfMonitorShown:_visible];
}

- (void)recordJsReport:(RNPMJsReport)report
{
  [_sampler recordJsReport:report];
}

#pragma mark - Window

- (nullable UIWindowScene *)activeWindowScene
{
  UIWindowScene *fallbackScene = nil;

  for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
      continue;
    }

    if (scene.activationState == UISceneActivationStateForegroundActive) {
      return (UIWindowScene *)scene;
    }

    fallbackScene = fallbackScene ?: (UIWindowScene *)scene;
  }

  return fallbackScene;
}

- (void)attachIfPossible
{
  UIWindowScene *scene = [self activeWindowScene];

  if (!_visible || _window != nil || scene == nil) {
    return;
  }

  __weak __typeof(self) weakSelf = self;
  RNPMOverlayViewController *rootViewController = [RNPMOverlayViewController new];

  rootViewController.onLayout = ^{
    [weakSelf layoutPanel];
  };

  _panel = [[RNPMPanelView alloc] initWithSampler:_sampler];
  _panel.expanded = [self storedExpandedState];
  [_panel addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
  [_panel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)]];

  _window = [[RNPMOverlayWindow alloc] initWithWindowScene:scene];
  _window.windowLevel = UIWindowLevelAlert + 1;
  _window.backgroundColor = UIColor.clearColor;
  _window.rootViewController = rootViewController;
  _window.interactiveView = _panel;
  _window.hidden = NO;

  [rootViewController.view addSubview:_panel];
  [self layoutPanel];

  _sampler.excludedWindow = _window;
  [_sampler start];
}

- (void)detach
{
  [_sampler stop];
  _window.hidden = YES;
  _window = nil;
  _panel = nil;
}

- (void)pauseSampling
{
  [_sampler stop];
}

- (void)resumeSampling
{
  if (_window != nil) {
    [_sampler start];
  }
}

#pragma mark - Layout

- (CGRect)allowedPanelArea
{
  UIView *container = _panel.superview;
  UIEdgeInsets safeArea = container.safeAreaInsets;
  CGRect safeBounds = UIEdgeInsetsInsetRect(container.bounds, safeArea);

  return CGRectInset(safeBounds, RNPMScreenMargin, RNPMScreenMargin);
}

- (CGPoint)clampedOrigin:(CGPoint)origin forSize:(CGSize)size
{
  CGRect area = [self allowedPanelArea];
  CGFloat maximumX = MAX(CGRectGetMaxX(area) - size.width, CGRectGetMinX(area));
  CGFloat maximumY = MAX(CGRectGetMaxY(area) - size.height, CGRectGetMinY(area));

  return CGPointMake(MIN(MAX(origin.x, CGRectGetMinX(area)), maximumX), MIN(MAX(origin.y, CGRectGetMinY(area)), maximumY));
}

- (void)layoutPanel
{
  if (_panel.superview == nil) {
    return;
  }

  CGSize size = [_panel preferredSize];
  CGPoint currentOrigin = CGRectIsEmpty(_panel.frame) ? [self storedOrigin] : _panel.frame.origin;
  CGPoint origin = [self clampedOrigin:currentOrigin forSize:size];

  _panel.frame = (CGRect){origin, size};
  [_panel setNeedsDisplay];
}

- (CGPoint)storedOrigin
{
  NSString *storedOrigin = [[NSUserDefaults standardUserDefaults] stringForKey:RNPMPanelOriginKey];

  if (storedOrigin == nil) {
    return [self allowedPanelArea].origin;
  }

  return CGPointFromString(storedOrigin);
}

- (void)storeOrigin:(CGPoint)origin
{
  [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGPoint(origin) forKey:RNPMPanelOriginKey];
}

- (BOOL)storedExpandedState
{
  id storedState = [[NSUserDefaults standardUserDefaults] objectForKey:RNPMPanelExpandedKey];

  return storedState != nil ? [storedState boolValue] : YES;
}

#pragma mark - Gestures

- (void)handlePan:(UIPanGestureRecognizer *)gesture
{
  CGPoint translation = [gesture translationInView:_panel.superview];

  if (gesture.state == UIGestureRecognizerStateBegan) {
    _panGestureStartOrigin = _panel.frame.origin;
    return;
  }

  CGPoint origin = CGPointMake(_panGestureStartOrigin.x + translation.x, _panGestureStartOrigin.y + translation.y);
  CGPoint clampedOrigin = [self clampedOrigin:origin forSize:_panel.frame.size];

  _panel.frame = (CGRect){clampedOrigin, _panel.frame.size};

  if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
    [self storeOrigin:clampedOrigin];
  }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture
{
  CGPoint location = [gesture locationInView:_panel];

  if (CGRectContainsPoint(_panel.closeButtonFrame, location)) {
    [self hide];
    return;
  }

  _panel.expanded = !_panel.isExpanded;
  [[NSUserDefaults standardUserDefaults] setBool:_panel.isExpanded forKey:RNPMPanelExpandedKey];
  [self layoutPanel];
}

#pragma mark - RNPMSamplerDelegate

- (BOOL)isAlertPresented
{
  for (UIWindow *window in _window.windowScene.windows) {
    UIViewController *controller = window.rootViewController;

    while (controller.presentedViewController != nil) {
      controller = controller.presentedViewController;
    }

    if ([controller isKindOfClass:[UIAlertController class]]) {
      return YES;
    }
  }

  return NO;
}

- (void)sampler:(RNPMSampler *)sampler didProduceSnapshot:(RNPMSnapshot)snapshot
{
  _panel.hidden = [self isAlertPresented];

  if (_panel.isExpanded) {
    [_panel setNeedsDisplay];
    return;
  }

  [self layoutPanel];
}

@end
