#import <UIKit/UIKit.h>

#import "RNPMSampler.h"

NS_ASSUME_NONNULL_BEGIN

@interface RNPMPanelView : UIView

@property (nonatomic, assign, getter=isExpanded) BOOL expanded;
@property (nonatomic, readonly) CGRect closeButtonFrame;

- (instancetype)initWithSampler:(RNPMSampler *)sampler NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (CGSize)preferredSize;

@end

NS_ASSUME_NONNULL_END
