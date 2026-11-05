#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNPMOverlayWindow : UIWindow

@property (nonatomic, weak, nullable) UIView *interactiveView;

@end

@interface RNPMOverlayViewController : UIViewController

@property (nonatomic, copy, nullable) void (^onLayout)(void);

@end

NS_ASSUME_NONNULL_END
