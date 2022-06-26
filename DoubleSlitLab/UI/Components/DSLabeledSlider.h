#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSLabeledSlider : NSView

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic) double minValue;
@property (nonatomic) double maxValue;
@property (nonatomic) double value;
@property (nonatomic) BOOL logarithmic;
@property (nonatomic) BOOL integerValues;
@property (nonatomic, copy, nullable) NSString * (^valueFormatter)(double value);
@property (nonatomic, copy, nullable) void (^onValueChanged)(double value);
@property (nonatomic, strong, readonly) NSSlider *slider;
@property (nonatomic, strong, readonly) NSTextField *valueLabel;

- (instancetype)initWithTitle:(NSString *)title
                     minValue:(double)minValue
                     maxValue:(double)maxValue
                        value:(double)value;

@end

NS_ASSUME_NONNULL_END
