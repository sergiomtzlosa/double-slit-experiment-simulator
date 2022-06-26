#import "DSTheme.h"
#import <QuartzCore/QuartzCore.h>

@implementation DSTheme

+ (NSColor *)background {
    return [NSColor colorWithSRGBRed:0.027 green:0.039 blue:0.059 alpha:1.0];
}
+ (NSColor *)panel {
    return [NSColor colorWithSRGBRed:0.047 green:0.063 blue:0.090 alpha:1.0];
}
+ (NSColor *)card {
    return [NSColor colorWithSRGBRed:0.063 green:0.086 blue:0.118 alpha:1.0];
}
+ (NSColor *)cardBorder {
    return [NSColor colorWithSRGBRed:0.137 green:0.180 blue:0.235 alpha:1.0];
}
+ (NSColor *)separator {
    return [NSColor colorWithSRGBRed:0.104 green:0.141 blue:0.190 alpha:1.0];
}
+ (NSColor *)textPrimary {
    return [NSColor colorWithSRGBRed:0.914 green:0.941 blue:0.973 alpha:1.0];
}
+ (NSColor *)textSecondary {
    return [NSColor colorWithSRGBRed:0.576 green:0.635 blue:0.714 alpha:1.0];
}
+ (NSColor *)textTertiary {
    return [NSColor colorWithSRGBRed:0.365 green:0.424 blue:0.502 alpha:1.0];
}
+ (NSColor *)liveGreen {
    return [NSColor colorWithSRGBRed:0.341 green:0.890 blue:0.537 alpha:1.0];
}
+ (NSColor *)warning {
    return [NSColor colorWithSRGBRed:0.949 green:0.757 blue:0.306 alpha:1.0];
}

+ (NSFont *)uiFontOfSize:(CGFloat)size weight:(NSFontWeight)weight {
    return [NSFont systemFontOfSize:size weight:weight];
}

+ (NSFont *)monoFontOfSize:(CGFloat)size weight:(NSFontWeight)weight {
    return [NSFont monospacedSystemFontOfSize:size weight:weight];
}

@end

@implementation DSCardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _fillColor = [DSTheme card];
        _borderColor = [DSTheme cardBorder];
        _cornerRadius = 12.0;
        _drawsBorder = YES;
    }
    return self;
}

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect
                                                        xRadius:self.cornerRadius
                                                        yRadius:self.cornerRadius];
    [self.fillColor setFill];
    [path fill];
    if (self.drawsBorder) {
        [self.borderColor setStroke];
        path.lineWidth = 1.0;
        [path stroke];
    }
}

@end

@implementation DSFlippedView

- (BOOL)isFlipped {
    return YES;
}

@end

@implementation DSSeparatorView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [DSTheme separator].CGColor;
    }
    return self;
}

@end

NSTextField *DSMakeLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = color;
    label.backgroundColor = NSColor.clearColor;
    label.bordered = NO;
    label.editable = NO;
    label.selectable = NO;
    label.drawsBackground = NO;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}


