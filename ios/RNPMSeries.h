#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNPMSeries : NSObject

@property (nonatomic, readonly) NSUInteger capacity;
@property (nonatomic, readonly) NSUInteger count;

- (instancetype)initWithCapacity:(NSUInteger)capacity NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)push:(double)value;
- (void)removeAllValues;
- (double)valueAtIndex:(NSUInteger)index;
- (double)minimumValue;
- (double)maximumValue;

@end

NS_ASSUME_NONNULL_END
