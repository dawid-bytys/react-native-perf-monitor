#import "RNPMPanelView.h"

static const CGFloat RNPMExpandedWidth = 296;
static const CGFloat RNPMPadding = 12;
static const CGFloat RNPMHeaderHeight = 24;
static const CGFloat RNPMHeaderGap = 8;
static const CGFloat RNPMRowHeight = 40;
static const CGFloat RNPMValueColumnWidth = 100;
static const CGFloat RNPMSparklineHeight = 22;
static const CGFloat RNPMSeparatorGap = 10;
static const CGFloat RNPMTileHeight = 34;
static const CGFloat RNPMTileGap = 8;
static const CGFloat RNPMCollapsedHeight = 30;
static const CGFloat RNPMCollapsedSegmentGap = 10;
static const CGFloat RNPMCornerRadius = 14;
static const NSInteger RNPMMetricRowCount = 5;
static const double RNPMBytesPerMegabyte = 1024 * 1024;

static UIColor *RNPMColorFromHex(uint32_t hex, CGFloat alpha)
{
  return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                         green:((hex >> 8) & 0xFF) / 255.0
                          blue:(hex & 0xFF) / 255.0
                         alpha:alpha];
}

static UIColor *RNPMGoodColor(void)
{
  return RNPMColorFromHex(0x34D399, 1);
}

static UIColor *RNPMWarningColor(void)
{
  return RNPMColorFromHex(0xFBBF24, 1);
}

static UIColor *RNPMBadColor(void)
{
  return RNPMColorFromHex(0xF87171, 1);
}

static UIColor *RNPMAccentColor(void)
{
  return RNPMColorFromHex(0x60A5FA, 1);
}

static UIColor *RNPMPrimaryTextColor(void)
{
  return [UIColor colorWithWhite:1 alpha:0.96];
}

static UIColor *RNPMSecondaryTextColor(void)
{
  return RNPMColorFromHex(0x9CA3AF, 1);
}

static UIColor *RNPMMutedTextColor(void)
{
  return [UIColor colorWithWhite:1 alpha:0.38];
}

static UIColor *RNPMColorForFps(double fps, double targetFps)
{
  double ratio = targetFps > 0 ? fps / targetFps : 0;

  if (ratio >= 0.9) {
    return RNPMGoodColor();
  }

  if (ratio >= 0.6) {
    return RNPMWarningColor();
  }

  return RNPMBadColor();
}

static UIColor *RNPMColorForCpu(double cpuPercent)
{
  if (cpuPercent < 60) {
    return RNPMGoodColor();
  }

  if (cpuPercent < 100) {
    return RNPMWarningColor();
  }

  return RNPMBadColor();
}

static UIColor *RNPMColorForRenderMs(double renderMs, double frameBudgetMs)
{
  if (renderMs < frameBudgetMs / 2) {
    return RNPMGoodColor();
  }

  if (renderMs < frameBudgetMs) {
    return RNPMWarningColor();
  }

  return RNPMBadColor();
}

static UIColor *RNPMColorForThermalState(RNPMThermalState state)
{
  switch (state) {
    case RNPMThermalStateNominal:
      return RNPMGoodColor();
    case RNPMThermalStateFair:
      return RNPMWarningColor();
    case RNPMThermalStateSerious:
    case RNPMThermalStateCritical:
      return RNPMBadColor();
    case RNPMThermalStateUnknown:
      return RNPMSecondaryTextColor();
  }
}

static NSString *RNPMThermalStateName(RNPMThermalState state)
{
  switch (state) {
    case RNPMThermalStateNominal:
      return @"Nominal";
    case RNPMThermalStateFair:
      return @"Fair";
    case RNPMThermalStateSerious:
      return @"Serious";
    case RNPMThermalStateCritical:
      return @"Critical";
    case RNPMThermalStateUnknown:
      return @"Unknown";
  }
}

static NSString *RNPMFormatThroughput(double bytesPerSecond)
{
  if (bytesPerSecond < 1024) {
    return [NSString stringWithFormat:@"%.0f B/s", bytesPerSecond];
  }

  if (bytesPerSecond < RNPMBytesPerMegabyte) {
    return [NSString stringWithFormat:@"%.1f KB/s", bytesPerSecond / 1024];
  }

  return [NSString stringWithFormat:@"%.1f MB/s", bytesPerSecond / RNPMBytesPerMegabyte];
}

static NSString *RNPMFormatCount(NSInteger count)
{
  return [NSNumberFormatter localizedStringFromNumber:@(count) numberStyle:NSNumberFormatterDecimalStyle];
}

@interface RNPMMetricRow : NSObject

@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy) NSString *unit;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) RNPMSeries *series;
@property (nonatomic, assign) double minimum;
@property (nonatomic, assign) double maximum;
@property (nonatomic, assign) double guide;

@end

@implementation RNPMMetricRow
@end

@implementation RNPMPanelView {
  RNPMSampler *_sampler;
  UIFont *_headerFont;
  UIFont *_labelFont;
  UIFont *_valueFont;
  UIFont *_unitFont;
  UIFont *_detailFont;
  UIFont *_tileValueFont;
  UIFont *_collapsedLabelFont;
  UIFont *_collapsedValueFont;
}

- (instancetype)initWithSampler:(RNPMSampler *)sampler
{
  if (self = [super initWithFrame:CGRectZero]) {
    _sampler = sampler;
    _expanded = YES;
    _headerFont = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    _labelFont = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
    _valueFont = [UIFont monospacedDigitSystemFontOfSize:19 weight:UIFontWeightSemibold];
    _unitFont = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    _detailFont = [UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightMedium];
    _tileValueFont = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    _collapsedLabelFont = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    _collapsedValueFont = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    self.opaque = NO;
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
    self.accessibilityIdentifier = @"react-native-perf-monitor";
  }

  return self;
}

- (CGSize)preferredSize
{
  if (!self.isExpanded) {
    return CGSizeMake([self collapsedWidth], RNPMCollapsedHeight);
  }

  CGFloat height = RNPMPadding + RNPMHeaderHeight + RNPMHeaderGap + RNPMMetricRowCount * RNPMRowHeight +
      RNPMSeparatorGap + RNPMTileHeight * 2 + RNPMTileGap + RNPMPadding;

  return CGSizeMake(RNPMExpandedWidth, height);
}

- (CGRect)closeButtonFrame
{
  if (!self.isExpanded) {
    return CGRectNull;
  }

  return CGRectMake(self.bounds.size.width - RNPMPadding - 24, RNPMPadding - 2, 28, 28);
}

- (void)drawRect:(CGRect)rect
{
  [self drawBackground];

  if (self.isExpanded) {
    [self drawExpandedContent];
    return;
  }

  [self drawCollapsedContent];
}

- (void)drawBackground
{
  CGFloat hairline = 1 / MAX(self.traitCollection.displayScale, 1);
  CGRect backgroundRect = CGRectInset(self.bounds, hairline / 2, hairline / 2);
  CGFloat radius = self.isExpanded ? RNPMCornerRadius : RNPMCollapsedHeight / 2;
  UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:backgroundRect cornerRadius:radius];

  [RNPMColorFromHex(0x111114, 0.96) setFill];
  [path fill];

  path.lineWidth = hairline;
  [[UIColor colorWithWhite:1 alpha:0.1] setStroke];
  [path stroke];
}

#pragma mark - Expanded

- (void)drawExpandedContent
{
  RNPMSnapshot snapshot = _sampler.latestSnapshot;
  CGFloat y = RNPMPadding;

  [self drawHeaderAtY:y snapshot:snapshot];
  y += RNPMHeaderHeight + RNPMHeaderGap;

  for (RNPMMetricRow *row in [self metricRowsForSnapshot:snapshot]) {
    [self drawMetricRow:row atY:y];
    y += RNPMRowHeight;
  }

  [self drawSeparatorAtY:y + RNPMSeparatorGap / 2 - 2];
  y += RNPMSeparatorGap;

  [self drawTilesAtY:y snapshot:snapshot];
}

- (void)drawHeaderAtY:(CGFloat)y snapshot:(RNPMSnapshot)snapshot
{
  UIColor *statusColor = RNPMColorForFps(snapshot.uiFps, snapshot.displayHz);
  CGRect dotRect = CGRectMake(RNPMPadding, y + 8, 8, 8);
  CGRect closeFrame = self.closeButtonFrame;
  NSString *refreshRate = [NSString stringWithFormat:@"%.0f Hz", snapshot.displayHz];

  [statusColor setFill];
  [[UIBezierPath bezierPathWithOvalInRect:dotRect] fill];

  [self drawText:@"PERF MONITOR"
              at:CGPointMake(CGRectGetMaxX(dotRect) + 7, y + 5)
            font:_headerFont
           color:RNPMPrimaryTextColor()
         kerning:1.4];
  [self drawRightAlignedText:refreshRate
                        atX:CGRectGetMinX(closeFrame) - 4
                          y:y + 6
                       font:_detailFont
                      color:RNPMSecondaryTextColor()];
  [self drawCloseGlyphInRect:closeFrame];
}

- (void)drawCloseGlyphInRect:(CGRect)frame
{
  CGRect glyphRect = CGRectInset(frame, 9, 9);
  UIBezierPath *path = [UIBezierPath bezierPath];

  [path moveToPoint:CGPointMake(CGRectGetMinX(glyphRect), CGRectGetMinY(glyphRect))];
  [path addLineToPoint:CGPointMake(CGRectGetMaxX(glyphRect), CGRectGetMaxY(glyphRect))];
  [path moveToPoint:CGPointMake(CGRectGetMaxX(glyphRect), CGRectGetMinY(glyphRect))];
  [path addLineToPoint:CGPointMake(CGRectGetMinX(glyphRect), CGRectGetMaxY(glyphRect))];
  path.lineWidth = 1.5;
  path.lineCapStyle = kCGLineCapRound;

  [RNPMSecondaryTextColor() setStroke];
  [path stroke];
}

- (NSArray<RNPMMetricRow *> *)metricRowsForSnapshot:(RNPMSnapshot)snapshot
{
  return @[
    [self uiRowForSnapshot:snapshot],
    [self jsRowForSnapshot:snapshot],
    [self cpuRowForSnapshot:snapshot],
    [self memoryRowForSnapshot:snapshot],
    [self reactRowForSnapshot:snapshot],
  ];
}

- (RNPMMetricRow *)uiRowForSnapshot:(RNPMSnapshot)snapshot
{
  RNPMMetricRow *row = [RNPMMetricRow new];

  row.label = @"UI THREAD";
  row.value = [NSString stringWithFormat:@"%.0f", snapshot.uiFps];
  row.unit = @"fps";
  row.detail = snapshot.droppedFrames > 0
      ? [NSString stringWithFormat:@"%ld dropped", (long)snapshot.droppedFrames]
      : @"smooth";
  row.color = RNPMColorForFps(snapshot.uiFps, snapshot.displayHz);
  row.series = _sampler.uiFpsSeries;
  row.maximum = MAX(snapshot.displayHz, [row.series maximumValue]);

  return row;
}

- (RNPMMetricRow *)jsRowForSnapshot:(RNPMSnapshot)snapshot
{
  RNPMMetricRow *row = [RNPMMetricRow new];

  row.label = @"JS THREAD";
  row.unit = @"fps";
  row.series = _sampler.jsFpsSeries;
  row.maximum = MAX(snapshot.jsTargetFps, [row.series maximumValue]);

  if (!snapshot.hasJsMetrics) {
    row.value = @"–";
    row.detail = @"import the package in JS";
    row.color = RNPMMutedTextColor();
    return row;
  }

  row.value = [NSString stringWithFormat:@"%.0f", snapshot.jsFps];
  row.detail = snapshot.isJsStalled ? @"stalled" : @"responsive";
  row.color = snapshot.isJsStalled ? RNPMBadColor() : RNPMColorForFps(snapshot.jsFps, snapshot.jsTargetFps);

  return row;
}

- (RNPMMetricRow *)cpuRowForSnapshot:(RNPMSnapshot)snapshot
{
  RNPMMetricRow *row = [RNPMMetricRow new];

  row.label = @"CPU";
  row.value = [NSString stringWithFormat:@"%.0f", snapshot.cpuPercent];
  row.unit = @"%";
  row.detail = [NSString stringWithFormat:@"%ld cores", (long)snapshot.cpuCores];
  row.color = RNPMColorForCpu(snapshot.cpuPercent);
  row.series = _sampler.cpuSeries;
  row.maximum = MAX(100, [row.series maximumValue]);

  return row;
}

- (RNPMMetricRow *)memoryRowForSnapshot:(RNPMSnapshot)snapshot
{
  RNPMMetricRow *row = [RNPMMetricRow new];
  double minimum = [_sampler.memorySeries minimumValue];
  double maximum = [_sampler.memorySeries maximumValue];
  double padding = MAX((maximum - minimum) * 0.2, RNPMBytesPerMegabyte);

  row.label = @"MEMORY";
  row.value = [NSString stringWithFormat:@"%.0f", snapshot.memoryBytes / RNPMBytesPerMegabyte];
  row.unit = @"MB";
  row.detail = snapshot.jsHeapTotalBytes > 0
      ? [NSString stringWithFormat:@"JS heap %.0f / %.0f MB",
                                   snapshot.jsHeapUsedBytes / RNPMBytesPerMegabyte,
                                   snapshot.jsHeapTotalBytes / RNPMBytesPerMegabyte]
      : @"physical footprint";
  row.color = RNPMAccentColor();
  row.series = _sampler.memorySeries;
  row.minimum = MAX(minimum - padding, 0);
  row.maximum = maximum + padding;

  return row;
}

- (RNPMMetricRow *)reactRowForSnapshot:(RNPMSnapshot)snapshot
{
  RNPMMetricRow *row = [RNPMMetricRow new];
  double frameBudgetMs = 1000 / MAX(snapshot.displayHz, 1);

  row.label = @"REACT COMMITS";
  row.unit = @"/s";
  row.series = _sampler.renderSeries;
  row.maximum = MAX(frameBudgetMs * 2, [row.series maximumValue]);
  row.guide = frameBudgetMs;

  if (!snapshot.hasJsMetrics) {
    row.value = @"–";
    row.detail = @"import the package in JS";
    row.color = RNPMMutedTextColor();
    return row;
  }

  row.value = [NSString stringWithFormat:@"%.0f", snapshot.reactCommitsPerSecond];
  row.detail = snapshot.reactCommitsPerSecond > 0
      ? [NSString stringWithFormat:@"avg %.1f · max %.1f ms", snapshot.reactRenderAvgMs, snapshot.reactRenderMaxMs]
      : @"idle";
  row.color = RNPMColorForRenderMs(snapshot.reactRenderMaxMs, frameBudgetMs);

  return row;
}

- (void)drawMetricRow:(RNPMMetricRow *)row atY:(CGFloat)y
{
  CGFloat width = self.bounds.size.width;
  CGFloat sparklineX = RNPMPadding + RNPMValueColumnWidth;
  CGRect sparklineRect = CGRectMake(sparklineX, y + 4, width - sparklineX - RNPMPadding, RNPMSparklineHeight);
  CGPoint valuePoint = CGPointMake(RNPMPadding, y + 12);
  CGFloat valueWidth = [self drawText:row.value at:valuePoint font:_valueFont color:row.color kerning:0];
  CGFloat unitY = valuePoint.y + _valueFont.ascender - _unitFont.ascender;

  [self drawText:row.label at:CGPointMake(RNPMPadding, y) font:_labelFont color:RNPMSecondaryTextColor() kerning:0.8];
  [self drawText:row.unit
              at:CGPointMake(valuePoint.x + valueWidth + 3, unitY)
            font:_unitFont
           color:RNPMSecondaryTextColor()
         kerning:0];
  [self drawSparklineForRow:row inRect:sparklineRect];
  [self drawRightAlignedText:row.detail
                        atX:width - RNPMPadding
                          y:CGRectGetMaxY(sparklineRect) + 2
                       font:_detailFont
                      color:RNPMSecondaryTextColor()];
}

- (void)drawSparklineForRow:(RNPMMetricRow *)row inRect:(CGRect)rect
{
  RNPMSeries *series = row.series;
  double range = MAX(row.maximum - row.minimum, 0.0001);
  CGFloat step = rect.size.width / MAX(series.capacity - 1, 1);
  CGFloat startX = CGRectGetMaxX(rect) - step * (series.count - 1);
  UIBezierPath *line = [UIBezierPath bezierPath];

  [self drawSparklineTrackInRect:rect];

  if (row.guide > 0 && row.guide < row.maximum) {
    [self drawGuideAtValue:row.guide row:row inRect:rect];
  }

  if (series.count < 2) {
    return;
  }

  for (NSUInteger index = 0; index < series.count; index++) {
    double normalized = MIN(MAX(([series valueAtIndex:index] - row.minimum) / range, 0), 1);
    CGPoint point = CGPointMake(startX + step * index, CGRectGetMaxY(rect) - normalized * rect.size.height);

    if (index == 0) {
      [line moveToPoint:point];
    } else {
      [line addLineToPoint:point];
    }
  }

  UIBezierPath *area = [line copy];

  [area addLineToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect))];
  [area addLineToPoint:CGPointMake(startX, CGRectGetMaxY(rect))];
  [area closePath];
  [[row.color colorWithAlphaComponent:0.16] setFill];
  [area fill];

  line.lineWidth = 1.5;
  line.lineJoinStyle = kCGLineJoinRound;
  [row.color setStroke];
  [line stroke];
}

- (void)drawSparklineTrackInRect:(CGRect)rect
{
  UIBezierPath *track = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 0, -1) cornerRadius:4];

  [[UIColor colorWithWhite:1 alpha:0.035] setFill];
  [track fill];
}

- (void)drawGuideAtValue:(double)value row:(RNPMMetricRow *)row inRect:(CGRect)rect
{
  double normalized = (value - row.minimum) / MAX(row.maximum - row.minimum, 0.0001);
  CGFloat y = CGRectGetMaxY(rect) - normalized * rect.size.height;
  UIBezierPath *guide = [UIBezierPath bezierPath];
  CGFloat dashPattern[] = {3, 3};

  [guide moveToPoint:CGPointMake(CGRectGetMinX(rect), y)];
  [guide addLineToPoint:CGPointMake(CGRectGetMaxX(rect), y)];
  [guide setLineDash:dashPattern count:2 phase:0];
  guide.lineWidth = 1;

  [[UIColor colorWithWhite:1 alpha:0.18] setStroke];
  [guide stroke];
}

- (void)drawSeparatorAtY:(CGFloat)y
{
  CGFloat hairline = 1 / MAX(self.traitCollection.displayScale, 1);
  CGRect separator = CGRectMake(RNPMPadding, y, self.bounds.size.width - RNPMPadding * 2, hairline);

  [[UIColor colorWithWhite:1 alpha:0.08] setFill];
  UIRectFill(separator);
}

- (void)drawTilesAtY:(CGFloat)y snapshot:(RNPMSnapshot)snapshot
{
  CGFloat tileWidth = (self.bounds.size.width - RNPMPadding * 2 - RNPMTileGap) / 2;
  CGFloat secondColumnX = RNPMPadding + tileWidth + RNPMTileGap;
  CGFloat secondRowY = y + RNPMTileHeight + RNPMTileGap;
  NSString *network = [NSString stringWithFormat:@"↓%@ ↑%@",
                                                 RNPMFormatThroughput(snapshot.networkDownBytesPerSecond),
                                                 RNPMFormatThroughput(snapshot.networkUpBytesPerSecond)];
  NSString *requests = snapshot.hasJsMetrics ? RNPMFormatCount(snapshot.activeRequests) : @"–";

  [self drawTileWithLabel:@"NATIVE VIEWS"
                    value:RNPMFormatCount(snapshot.viewCount)
               valueColor:RNPMPrimaryTextColor()
                   inRect:CGRectMake(RNPMPadding, y, tileWidth, RNPMTileHeight)];
  [self drawTileWithLabel:@"ACTIVE REQUESTS"
                    value:requests
               valueColor:RNPMPrimaryTextColor()
                   inRect:CGRectMake(secondColumnX, y, tileWidth, RNPMTileHeight)];
  [self drawTileWithLabel:@"NETWORK (DEVICE)"
                    value:network
               valueColor:RNPMPrimaryTextColor()
                   inRect:CGRectMake(RNPMPadding, secondRowY, tileWidth, RNPMTileHeight)];
  [self drawTileWithLabel:@"THERMAL STATE"
                    value:RNPMThermalStateName(snapshot.thermalState)
               valueColor:RNPMColorForThermalState(snapshot.thermalState)
                   inRect:CGRectMake(secondColumnX, secondRowY, tileWidth, RNPMTileHeight)];
}

- (void)drawTileWithLabel:(NSString *)label value:(NSString *)value valueColor:(UIColor *)valueColor inRect:(CGRect)rect
{
  UIBezierPath *background = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:8];
  UIFont *valueFont = [self fontForValue:value fittingWidth:rect.size.width - 16];

  [[UIColor colorWithWhite:1 alpha:0.05] setFill];
  [background fill];

  [self drawText:label
              at:CGPointMake(rect.origin.x + 8, rect.origin.y + 5)
            font:_labelFont
           color:RNPMSecondaryTextColor()
         kerning:0.6];
  [self drawText:value at:CGPointMake(rect.origin.x + 8, rect.origin.y + 17) font:valueFont color:valueColor kerning:0];
}

- (UIFont *)fontForValue:(NSString *)value fittingWidth:(CGFloat)width
{
  CGFloat valueWidth = [value sizeWithAttributes:@{NSFontAttributeName : _tileValueFont}].width;

  if (valueWidth <= width) {
    return _tileValueFont;
  }

  CGFloat fittingSize = floor(_tileValueFont.pointSize * width / valueWidth);

  return [UIFont monospacedDigitSystemFontOfSize:MAX(fittingSize, 8) weight:UIFontWeightSemibold];
}

#pragma mark - Collapsed

- (NSArray<NSArray *> *)collapsedSegments
{
  RNPMSnapshot snapshot = _sampler.latestSnapshot;
  NSString *jsValue = snapshot.hasJsMetrics ? [NSString stringWithFormat:@"%.0f", snapshot.jsFps] : @"–";
  UIColor *jsColor = snapshot.hasJsMetrics
      ? (snapshot.isJsStalled ? RNPMBadColor() : RNPMColorForFps(snapshot.jsFps, snapshot.jsTargetFps))
      : RNPMMutedTextColor();

  return @[
    @[ @"UI", [NSString stringWithFormat:@"%.0f", snapshot.uiFps], RNPMColorForFps(snapshot.uiFps, snapshot.displayHz) ],
    @[ @"JS", jsValue, jsColor ],
    @[ @"CPU", [NSString stringWithFormat:@"%.0f%%", snapshot.cpuPercent], RNPMColorForCpu(snapshot.cpuPercent) ],
    @[
      @"RAM",
      [NSString stringWithFormat:@"%.0f", snapshot.memoryBytes / RNPMBytesPerMegabyte],
      RNPMAccentColor(),
    ],
  ];
}

- (CGFloat)collapsedWidth
{
  CGFloat width = RNPMPadding * 2;

  for (NSArray *segment in [self collapsedSegments]) {
    width += [self widthOfCollapsedSegment:segment] + RNPMCollapsedSegmentGap;
  }

  return ceil(width - RNPMCollapsedSegmentGap);
}

- (CGFloat)widthOfCollapsedSegment:(NSArray *)segment
{
  CGFloat labelWidth = [segment[0] sizeWithAttributes:@{NSFontAttributeName : _collapsedLabelFont}].width;
  CGFloat valueWidth = [segment[1] sizeWithAttributes:@{NSFontAttributeName : _collapsedValueFont}].width;

  return labelWidth + 4 + valueWidth;
}

- (void)drawCollapsedContent
{
  CGFloat x = RNPMPadding;
  CGFloat valueY = (RNPMCollapsedHeight - _collapsedValueFont.lineHeight) / 2;
  CGFloat labelY = valueY + _collapsedValueFont.ascender - _collapsedLabelFont.ascender;

  for (NSArray *segment in [self collapsedSegments]) {
    CGFloat labelWidth = [self drawText:segment[0]
                                     at:CGPointMake(x, labelY)
                                   font:_collapsedLabelFont
                                  color:RNPMSecondaryTextColor()
                                kerning:0];
    CGFloat valueWidth = [self drawText:segment[1]
                                     at:CGPointMake(x + labelWidth + 4, valueY)
                                   font:_collapsedValueFont
                                  color:segment[2]
                                kerning:0];

    x += labelWidth + 4 + valueWidth + RNPMCollapsedSegmentGap;
  }
}

#pragma mark - Text

- (CGFloat)drawText:(NSString *)text at:(CGPoint)point font:(UIFont *)font color:(UIColor *)color kerning:(CGFloat)kerning
{
  NSDictionary *attributes = @{
    NSFontAttributeName : font,
    NSForegroundColorAttributeName : color,
    NSKernAttributeName : @(kerning),
  };

  [text drawAtPoint:point withAttributes:attributes];

  return [text sizeWithAttributes:attributes].width;
}

- (void)drawRightAlignedText:(NSString *)text atX:(CGFloat)x y:(CGFloat)y font:(UIFont *)font color:(UIColor *)color
{
  NSDictionary *attributes = @{
    NSFontAttributeName : font,
    NSForegroundColorAttributeName : color,
  };
  CGFloat width = [text sizeWithAttributes:attributes].width;

  [text drawAtPoint:CGPointMake(x - width, y) withAttributes:attributes];
}

@end
