#import <Foundation/Foundation.h>

#import "RNPMSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const RNPMVisibilityDidChangeNotification;
FOUNDATION_EXPORT NSString *const RNPMVisibilityKey;

@interface RNPMOverlayController : NSObject

@property (atomic, readonly, getter=isVisible) BOOL visible;
@property (nonatomic, weak, nullable) id devSettings;

+ (instancetype)sharedController;

- (void)show;
- (void)hide;
- (void)toggle;
- (void)showFromDevMenu;
- (void)hideFromDevMenu;
- (void)restoreVisibilityOnLaunch;
- (void)recordJsReport:(RNPMJsReport)report;

@end

NS_ASSUME_NONNULL_END
