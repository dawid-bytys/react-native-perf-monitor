#import <UIKit/UIKit.h>

#import "RNPMSeries.h"
#import "RNPMSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

@class RNPMSampler;

@protocol RNPMSamplerDelegate <NSObject>

- (void)sampler:(RNPMSampler *)sampler didProduceSnapshot:(RNPMSnapshot)snapshot;

@end

@interface RNPMSampler : NSObject

@property (nonatomic, weak, nullable) id<RNPMSamplerDelegate> delegate;
@property (nonatomic, weak, nullable) UIWindow *excludedWindow;
@property (nonatomic, readonly) RNPMSnapshot latestSnapshot;
@property (nonatomic, readonly) RNPMSeries *uiFpsSeries;
@property (nonatomic, readonly) RNPMSeries *jsFpsSeries;
@property (nonatomic, readonly) RNPMSeries *cpuSeries;
@property (nonatomic, readonly) RNPMSeries *memorySeries;
@property (nonatomic, readonly) RNPMSeries *renderSeries;

- (void)start;
- (void)stop;
- (void)recordJsReport:(RNPMJsReport)report;

@end

NS_ASSUME_NONNULL_END
