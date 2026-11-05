#import "RNPMSeries.h"

@implementation RNPMSeries {
  double *_values;
  NSUInteger _start;
}

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
  if (self = [super init]) {
    _capacity = MAX(capacity, 1);
    _values = calloc(_capacity, sizeof(double));
  }

  return self;
}

- (void)dealloc
{
  free(_values);
}

- (void)push:(double)value
{
  if (_count < _capacity) {
    _values[(_start + _count) % _capacity] = value;
    _count += 1;
    return;
  }

  _values[_start] = value;
  _start = (_start + 1) % _capacity;
}

- (void)removeAllValues
{
  _start = 0;
  _count = 0;
}

- (double)valueAtIndex:(NSUInteger)index
{
  return _values[(_start + index) % _capacity];
}

- (double)minimumValue
{
  double minimum = _count > 0 ? [self valueAtIndex:0] : 0;

  for (NSUInteger index = 1; index < _count; index++) {
    minimum = MIN(minimum, [self valueAtIndex:index]);
  }

  return minimum;
}

- (double)maximumValue
{
  double maximum = _count > 0 ? [self valueAtIndex:0] : 0;

  for (NSUInteger index = 1; index < _count; index++) {
    maximum = MAX(maximum, [self valueAtIndex:index]);
  }

  return maximum;
}

@end
