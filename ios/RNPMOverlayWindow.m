#import "RNPMOverlayWindow.h"

@implementation RNPMOverlayWindow

- (BOOL)canBecomeKeyWindow
{
  return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  UIView *hitView = [super hitTest:point withEvent:event];

  if (self.rootViewController.presentedViewController != nil) {
    return hitView;
  }

  if (self.interactiveView != nil && [hitView isDescendantOfView:self.interactiveView]) {
    return hitView;
  }

  return nil;
}

@end

@implementation RNPMOverlayViewController

- (void)loadView
{
  UIView *view = [UIView new];

  view.backgroundColor = UIColor.clearColor;
  self.view = view;
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];

  if (self.onLayout != nil) {
    self.onLayout();
  }
}

- (nullable UIViewController *)hostViewController
{
  UIWindowScene *scene = self.view.window.windowScene;

  for (UIWindow *window in scene.windows) {
    if (window == self.view.window || !window.isKeyWindow) {
      continue;
    }

    UIViewController *controller = window.rootViewController;

    while (controller.presentedViewController != nil) {
      controller = controller.presentedViewController;
    }

    return controller;
  }

  return nil;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
  UIViewController *host = [self hostViewController];

  return host != nil ? host.preferredStatusBarStyle : UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden
{
  return [self hostViewController].prefersStatusBarHidden;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
  UIViewController *host = [self hostViewController];

  return host != nil ? host.supportedInterfaceOrientations : UIInterfaceOrientationMaskAll;
}

@end
