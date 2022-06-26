#import "DSPatternView.h"
#import "DSTheme.h"
#import <math.h>

@implementation DSPatternView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        _accentColor = [NSColor whiteColor];
        [self setContentHuggingPriority:NSLayoutPriorityDefaultLow
                         forOrientation:NSLayoutConstraintOrientationVertical];
    }
    return self;
}

- (void)setPatternImage:(NSImage *)patternImage {
    _patternImage = patternImage;
    [self setNeedsDisplay:YES];
}

- (void)setShutterClosed:(BOOL)shutterClosed {
    _shutterClosed = shutterClosed;
    [self setNeedsDisplay:YES];
}

- (void)setAccentColor:(NSColor *)accentColor {
    _accentColor = accentColor ?: [NSColor whiteColor];
    [self setNeedsDisplay:YES];
}

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = NSInsetRect(self.bounds, 1.0, 1.0);
    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8.0 yRadius:8.0];

    [[NSColor blackColor] setFill];
    [clip fill];

    [NSGraphicsContext saveGraphicsState];
    [clip addClip];
    if (self.patternImage) {
        NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;
        [self.patternImage drawInRect:rect
                             fromRect:NSZeroRect
                            operation:NSCompositingOperationSourceOver
                             fraction:1.0
                       respectFlipped:YES
                                hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
    }

    // Centre scanline used by the intensity plot.
    NSColor *lineColor = [self.accentColor colorWithAlphaComponent:0.28];
    [lineColor setStroke];
    NSBezierPath *hline = [NSBezierPath bezierPath];
    CGFloat pattern[] = {3.0, 4.0};
    [hline setLineDash:pattern count:2 phase:0.0];
    hline.lineWidth = 0.8;
    [hline moveToPoint:NSMakePoint(NSMinX(rect) + 8.0, NSMidY(rect))];
    [hline lineToPoint:NSMakePoint(NSMaxX(rect) - 8.0, NSMidY(rect))];
    [hline stroke];

    [[[NSColor whiteColor] colorWithAlphaComponent:0.06] setStroke];
    NSBezierPath *vline = [NSBezierPath bezierPath];
    [vline moveToPoint:NSMakePoint(NSMidX(rect), NSMinY(rect) + 8.0)];
    [vline lineToPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect) - 8.0)];
    vline.lineWidth = 0.8;
    [vline stroke];

    if (!self.patternImage) {
        [self drawCenteredMessage:@"Preparing detector…" subtitle:nil dim:NO];
    }

    if (self.shutterClosed) {
        [[NSColor colorWithSRGBRed:0.01 green:0.02 blue:0.03 alpha:0.78] setFill];
        [clip fill];
        [self drawCenteredMessage:@"SHUTTER CLOSED" subtitle:@"Open the laser to expose the screen" dim:YES];
    }
    [NSGraphicsContext restoreGraphicsState];

    [[[NSColor whiteColor] colorWithAlphaComponent:0.09] setStroke];
    clip.lineWidth = 1.0;
    [clip stroke];
}

- (void)drawCenteredMessage:(NSString *)message subtitle:(nullable NSString *)subtitle dim:(BOOL)dim {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    NSColor *color = dim ? [DSTheme textSecondary] : [DSTheme textTertiary];
    NSDictionary *attrs = @{
        NSFontAttributeName: [DSTheme uiFontOfSize:11.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style
    };
    CGFloat centerY = NSMidY(self.bounds);
    [message drawInRect:NSMakeRect(10.0, centerY - (subtitle ? 2.0 : 6.0), NSWidth(self.bounds) - 20.0, 18.0)
        withAttributes:attrs];
    if (subtitle) {
        NSDictionary *subAttrs = @{
            NSFontAttributeName: [DSTheme uiFontOfSize:10.0 weight:NSFontWeightRegular],
            NSForegroundColorAttributeName: [DSTheme textTertiary],
            NSParagraphStyleAttributeName: style
        };
        [subtitle drawInRect:NSMakeRect(10.0, centerY - 18.0, NSWidth(self.bounds) - 20.0, 16.0)
              withAttributes:subAttrs];
    }
}

@end

@implementation DSProfileView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        _accentColor = [NSColor whiteColor];
    }
    return self;
}

- (BOOL)isOpaque {
    return NO;
}

- (void)setProfileData:(NSData *)data count:(NSUInteger)count xHalfRangeMm:(double)xHalfRangeMm accentColor:(NSColor *)accentColor {
    _profileData = [data copy];
    _profileLength = count;
    _xHalfRangeMm = xHalfRangeMm;
    _accentColor = accentColor ?: [NSColor whiteColor];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    CGFloat left = 34.0;
    CGFloat right = 10.0;
    CGFloat top = 10.0;
    CGFloat bottom = 22.0;
    NSRect plot = NSMakeRect(left,
                             bottom,
                             MAX(10.0, NSWidth(self.bounds) - left - right),
                             MAX(10.0, NSHeight(self.bounds) - top - bottom));

    NSColor *grid = [[DSTheme separator] colorWithAlphaComponent:0.85];
    NSColor *labelColor = [DSTheme textTertiary];
    NSFont *axisFont = [DSTheme monoFontOfSize:8.5 weight:NSFontWeightRegular];

    for (NSInteger i = 0; i <= 4; i++) {
        CGFloat t = (CGFloat)i / 4.0;
        CGFloat y = NSMinY(plot) + t * NSHeight(plot);
        NSBezierPath *line = [NSBezierPath bezierPath];
        [line moveToPoint:NSMakePoint(NSMinX(plot), y)];
        [line lineToPoint:NSMakePoint(NSMaxX(plot), y)];
        [(i == 0 ? grid : [grid colorWithAlphaComponent:0.45]) setStroke];
        line.lineWidth = 0.5;
        [line stroke];

        NSDictionary *attrs = @{
            NSFontAttributeName: axisFont,
            NSForegroundColorAttributeName: labelColor
        };
        NSString *valueString = i == 0 ? @"0" : (i == 2 ? @"0.5" : (i == 4 ? @"1" : @""));
        if (valueString.length > 0) {
            [valueString drawInRect:NSMakeRect(0.0, y - 5.0, left - 6.0, 12.0)
                     withAttributes:attrs];
        }
    }

    NSBezierPath *axis = [NSBezierPath bezierPath];
    [axis moveToPoint:NSMakePoint(NSMinX(plot), NSMinY(plot))];
    [axis lineToPoint:NSMakePoint(NSMaxX(plot), NSMinY(plot))];
    [[DSTheme separator] setStroke];
    axis.lineWidth = 0.8;
    [axis stroke];

    double scale = self.xHalfRangeMm < 1.0 ? 1000.0 : 1.0;
    double lowValue = -self.xHalfRangeMm * scale;
    double highValue = self.xHalfRangeMm * scale;
    NSString *(^formatAxis)(double) = ^NSString *(double value) {
        if (fabs(value) < 1e-9) return @"0";
        if (fabs(value) >= 100.0) return [NSString stringWithFormat:@"%.0f", value];
        if (fabs(value) >= 10.0) return [NSString stringWithFormat:@"%.1f", value];
        return [NSString stringWithFormat:@"%.2f", value];
    };
    NSArray<NSString *> *xLabels = @[formatAxis(lowValue), @"0", formatAxis(highValue)];
    NSArray<NSNumber *> *xPositions = @[@(NSMinX(plot)), @(NSMidX(plot)), @(NSMaxX(plot))];
    for (NSUInteger i = 0; i < xLabels.count; i++) {
        CGFloat centerX = xPositions[i].doubleValue;
        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        ps.alignment = i == 0 ? NSTextAlignmentLeft : (i == 2 ? NSTextAlignmentRight : NSTextAlignmentCenter);
        NSDictionary *attrs = @{
            NSFontAttributeName: axisFont,
            NSForegroundColorAttributeName: labelColor,
            NSParagraphStyleAttributeName: ps
        };
        CGFloat labelWidth = i == 1 ? 40.0 : (NSWidth(plot) / 2.0);
        CGFloat xOrigin = i == 0 ? centerX : (i == 2 ? centerX - labelWidth : centerX - labelWidth / 2.0);
        [xLabels[i] drawInRect:NSMakeRect(xOrigin, 4.0, labelWidth, 12.0) withAttributes:attrs];
    }

    if (!self.profileData || self.profileLength < 2) {
        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        ps.alignment = NSTextAlignmentCenter;
        [@"Awaiting simulation" drawInRect:NSInsetRect(plot, 0.0, NSHeight(plot) / 2.0 - 8.0)
                           withAttributes:@{NSFontAttributeName: [DSTheme uiFontOfSize:10.5 weight:NSFontWeightRegular],
                                            NSForegroundColorAttributeName: [DSTheme textTertiary],
                                            NSParagraphStyleAttributeName: ps}];
        return;
    }

    const float *values = self.profileData.bytes;
    NSUInteger count = MIN(self.profileLength, self.profileData.length / sizeof(float));
    NSBezierPath *curve = [NSBezierPath bezierPath];
    for (NSUInteger i = 0; i < count; i++) {
        CGFloat t = count > 1 ? (CGFloat)i / (CGFloat)(count - 1) : 0.0;
        CGFloat x = NSMinX(plot) + t * NSWidth(plot);
        CGFloat y = NSMinY(plot) + MIN(1.0, MAX(0.0, values[i])) * NSHeight(plot);
        if (i == 0) {
            [curve moveToPoint:NSMakePoint(x, y)];
        } else {
            [curve lineToPoint:NSMakePoint(x, y)];
        }
    }

    NSBezierPath *area = [curve copy];
    [area lineToPoint:NSMakePoint(NSMaxX(plot), NSMinY(plot))];
    [area lineToPoint:NSMakePoint(NSMinX(plot), NSMinY(plot))];
    [area closePath];

    [NSGraphicsContext saveGraphicsState];
    [area addClip];
    NSColor *topColor = [self.accentColor colorWithAlphaComponent:0.30];
    NSColor *bottomColor = [self.accentColor colorWithAlphaComponent:0.015];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:bottomColor endingColor:topColor];
    [gradient drawInRect:plot angle:90.0];
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *glow = [curve copy];
    glow.lineWidth = 4.0;
    glow.lineJoinStyle = NSLineJoinStyleRound;
    [[self.accentColor colorWithAlphaComponent:0.12] setStroke];
    [glow stroke];

    curve.lineWidth = 1.4;
    curve.lineJoinStyle = NSLineJoinStyleRound;
    [[self.accentColor colorWithAlphaComponent:0.95] setStroke];
    [curve stroke];

    NSBezierPath *centerMark = [NSBezierPath bezierPath];
    [centerMark moveToPoint:NSMakePoint(NSMidX(plot), NSMinY(plot))];
    [centerMark lineToPoint:NSMakePoint(NSMidX(plot), NSMaxY(plot))];
    CGFloat dash[] = {2.0, 4.0};
    [centerMark setLineDash:dash count:2 phase:0.0];
    centerMark.lineWidth = 0.6;
    [[[NSColor whiteColor] colorWithAlphaComponent:0.10] setStroke];
    [centerMark stroke];
}

@end
