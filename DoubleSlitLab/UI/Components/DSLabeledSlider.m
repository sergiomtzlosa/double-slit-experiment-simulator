#import "DSLabeledSlider.h"
#import "DSTheme.h"
#import <math.h>

@interface DSLabeledSlider ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, strong, readwrite) NSSlider *slider;
@property (nonatomic, strong, readwrite) NSTextField *valueLabel;
@property (nonatomic, strong) NSTextField *titleLabel;
@end

@implementation DSLabeledSlider

- (instancetype)initWithTitle:(NSString *)title
                     minValue:(double)minValue
                     maxValue:(double)maxValue
                        value:(double)value {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        _title = [title copy];
        _minValue = minValue;
        _maxValue = maxValue;

        _titleLabel = DSMakeLabel(title, [DSTheme uiFontOfSize:11.5 weight:NSFontWeightMedium], [DSTheme textSecondary]);
        _valueLabel = DSMakeLabel(@"", [DSTheme monoFontOfSize:10.5 weight:NSFontWeightMedium], [DSTheme textPrimary]);
        _valueLabel.alignment = NSTextAlignmentRight;

        _slider = [NSSlider sliderWithValue:0.5 minValue:0.0 maxValue:1.0 target:self action:@selector(sliderChanged:)];
        _slider.continuous = YES;
        _slider.controlSize = NSControlSizeSmall;
        _slider.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:_titleLabel];
        [self addSubview:_valueLabel];
        [self addSubview:_slider];

        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
        [_valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
        [_valueLabel.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor].active = YES;
        [_valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:_titleLabel.trailingAnchor constant:8.0].active = YES;
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_valueLabel.leadingAnchor constant:-8.0].active = YES;

        [_slider.leadingAnchor constraintEqualToAnchor:self.leadingAnchor].active = YES;
        [_slider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor].active = YES;
        [_slider.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:3.0].active = YES;
        [_slider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;
        [_slider.heightAnchor constraintGreaterThanOrEqualToConstant:18.0].active = YES;

        self.minValue = minValue;
        self.maxValue = maxValue;
        [self setValue:value];
    }
    return self;
}

- (void)setMinValue:(double)minValue {
    _minValue = minValue;
    if (self.value < minValue) {
        [self setValue:minValue];
    }
}

- (void)setMaxValue:(double)maxValue {
    _maxValue = maxValue;
    if (self.value > maxValue) {
        [self setValue:maxValue];
    }
}

- (void)setIntegerValues:(BOOL)integerValues {
    _integerValues = integerValues;
    if (integerValues) {
        NSInteger marks = (NSInteger)(self.maxValue - self.minValue) + 1;
        if (marks >= 2 && marks <= 12) {
            self.slider.numberOfTickMarks = marks;
            self.slider.allowsTickMarkValuesOnly = YES;
        }
    } else {
        self.slider.numberOfTickMarks = 0;
        self.slider.allowsTickMarkValuesOnly = NO;
    }
    [self updateDisplay];
}

- (double)normalizedForValue:(double)value {
    if (self.maxValue <= self.minValue) {
        return 0.0;
    }
    if (self.logarithmic) {
        double low = log(fmax(self.minValue, 1e-9));
        double high = log(fmax(self.maxValue, self.minValue + 1e-9));
        double v = log(fmax(value, self.minValue));
        return (v - low) / (high - low);
    }
    return (value - self.minValue) / (self.maxValue - self.minValue);
}

- (double)valueForNormalized:(double)normalized {
    double t = fmin(1.0, fmax(0.0, normalized));
    double value;
    if (self.logarithmic) {
        double low = log(fmax(self.minValue, 1e-9));
        double high = log(fmax(self.maxValue, self.minValue + 1e-9));
        value = exp(low + t * (high - low));
    } else {
        value = self.minValue + t * (self.maxValue - self.minValue);
    }
    if (self.integerValues) {
        value = round(value);
    }
    return value;
}

- (void)setValue:(double)value {
    double clamped = fmin(self.maxValue, fmax(self.minValue, value));
    if (self.integerValues) {
        clamped = round(clamped);
    }
    _value = clamped;
    self.slider.doubleValue = [self normalizedForValue:clamped];
    [self updateDisplay];
}

- (void)sliderChanged:(NSSlider *)sender {
    double newValue = [self valueForNormalized:sender.doubleValue];
    newValue = fmin(self.maxValue, fmax(self.minValue, newValue));
    _value = newValue;
    [self updateDisplay];
    if (self.onValueChanged) {
        self.onValueChanged(newValue);
    }
}

- (void)updateDisplay {
    NSString *formatted;
    if (self.valueFormatter) {
        formatted = self.valueFormatter(self.value);
    } else {
        formatted = [NSString stringWithFormat:@"%.3g", self.value];
    }
    self.valueLabel.stringValue = formatted ?: @"";
}

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSString *)accessibilityLabel {
    return self.title;
}

@end
