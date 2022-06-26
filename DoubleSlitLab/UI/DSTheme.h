#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSTheme : NSObject

+ (NSColor *)background;
+ (NSColor *)panel;
+ (NSColor *)card;
+ (NSColor *)cardBorder;
+ (NSColor *)separator;
+ (NSColor *)textPrimary;
+ (NSColor *)textSecondary;
+ (NSColor *)textTertiary;
+ (NSColor *)liveGreen;
+ (NSColor *)warning;

+ (NSFont *)uiFontOfSize:(CGFloat)size weight:(NSFontWeight)weight;
+ (NSFont *)monoFontOfSize:(CGFloat)size weight:(NSFontWeight)weight;

@end

@interface DSCardView : NSView
@property (nonatomic, strong) NSColor *fillColor;
@property (nonatomic, strong) NSColor *borderColor;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) BOOL drawsBorder;
@end

@interface DSFlippedView : NSView
@end

@interface DSSeparatorView : NSView
@end

FOUNDATION_EXPORT NSTextField *DSMakeLabel(NSString *text, NSFont *font, NSColor *color);

NS_ASSUME_NONNULL_END
