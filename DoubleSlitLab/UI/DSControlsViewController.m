#import "DSControlsViewController.h"
#import "DSExperimentParameters.h"
#import "DSLabeledSlider.h"
#import "DSTheme.h"
#import <QuartzCore/QuartzCore.h>

@interface DSControlsViewController ()
@property (nonatomic, strong) NSPopUpButton *laserPopup;
@property (nonatomic, strong) NSColorWell *colorWell;
@property (nonatomic, strong) NSSegmentedControl *coherenceControl;
@property (nonatomic, strong) DSLabeledSlider *wavelengthSlider;
@property (nonatomic, strong) DSLabeledSlider *linewidthSlider;
@property (nonatomic, strong) DSLabeledSlider *sourceDistanceSlider;
@property (nonatomic, strong) DSLabeledSlider *slitCountSlider;
@property (nonatomic, strong) DSLabeledSlider *slitWidthSlider;
@property (nonatomic, strong) DSLabeledSlider *slitLengthSlider;
@property (nonatomic, strong) DSLabeledSlider *slitPitchSlider;
@property (nonatomic, strong) DSLabeledSlider *screenDistanceSlider;
@property (nonatomic, strong) NSSwitch *shutterSwitch;
@property (nonatomic, strong) NSView *laserSwatch;
@end

@implementation DSControlsViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _parameters = [DSExperimentParameters defaultParameters];
    }
    return self;
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 304.0, 900.0)];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [DSTheme panel].CGColor;
    self.view = root;
    [self buildInterface];
}

- (void)buildInterface {
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    scrollView.borderType = NSNoBorder;
    scrollView.scrollerStyle = NSScrollerStyleOverlay;
    [self.view addSubview:scrollView];

    DSFlippedView *documentView = [[DSFlippedView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 300.0, 900.0)];
    documentView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = documentView;

    NSStackView *stack = [[NSStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.distribution = NSStackViewDistributionFill;
    stack.spacing = 16.0;
    [documentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [documentView.leadingAnchor constraintEqualToAnchor:scrollView.contentView.leadingAnchor],
        [documentView.topAnchor constraintEqualToAnchor:scrollView.contentView.topAnchor],
        [documentView.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor],

        [stack.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:18.0],
        [stack.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-18.0],
        [stack.topAnchor constraintEqualToAnchor:documentView.topAnchor constant:20.0],
        [stack.bottomAnchor constraintEqualToAnchor:documentView.bottomAnchor constant:-24.0],
    ]];

    NSView *header = [self buildHeader];
    [stack addArrangedSubview:header];
    [header.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    [stack addArrangedSubview:[self separator]];

    NSStackView *lightSection = [self sectionWithTitle:@"LIGHT SOURCE" views:@[
        [self labeledPopupRow],
        [self colorRow],
        [self wavelengthSlider],
        [self coherenceRow],
        [self linewidthSlider],
        [self sourceDistanceSlider]
    ]];
    [self addFullWidthSection:lightSection toStack:stack];
    [stack addArrangedSubview:[self separator]];

    NSStackView *apertureSection = [self sectionWithTitle:@"APERTURE" views:@[
        [self slitCountSlider],
        [self slitWidthSlider],
        [self slitLengthSlider],
        [self slitPitchSlider],
        [self noteLabel:@"Slit pitch is centre-to-centre spacing."]
    ]];
    [self addFullWidthSection:apertureSection toStack:stack];
    [stack addArrangedSubview:[self separator]];

    NSStackView *screenSection = [self sectionWithTitle:@"DETECTOR" views:@[
        [self screenDistanceSlider],
        [self noteLabel:@"Screen range is auto-fitted to the pattern."]
    ]];
    [self addFullWidthSection:screenSection toStack:stack];
    [stack addArrangedSubview:[self separator]];

    NSStackView *displaySection = [self sectionWithTitle:@"DISPLAY" views:@[
        [self shutterRow],
        [self noteLabel:@"Far-field (Fraunhofer) scalar model. The 3D aperture is enlarged for visibility."]
    ]];
    [self addFullWidthSection:displaySection toStack:stack];

    NSButton *resetButton = [NSButton buttonWithTitle:@"Reset All Settings"
                                               target:self
                                               action:@selector(resetExperiment)];
    resetButton.bezelStyle = NSBezelStyleRounded;
    resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    resetButton.controlSize = NSControlSizeRegular;
    [stack addArrangedSubview:resetButton];
    [resetButton.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    NSTextField *formula = DSMakeLabel(@"I(θ) = sinc²(πα/λ) · [sin(Nβ) / (N sin β)]²",
                                       [DSTheme monoFontOfSize:9.5 weight:NSFontWeightRegular],
                                       [DSTheme textTertiary]);
    formula.toolTip = @"Fraunhofer intensity for a monochromatic coherent source; the vertical slit-length envelope is included in the render.";
    [stack addArrangedSubview:formula];
    [formula.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self syncWithParameters];
    });
}

- (NSView *)buildHeader {
    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *dot = [[NSView alloc] initWithFrame:NSZeroRect];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 4.0;
    dot.layer.backgroundColor = self.parameters.beamColor.CGColor;
    self.laserSwatch = dot;

    NSTextField *kicker = DSMakeLabel(@"OPTICAL BENCH", [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold], [DSTheme textTertiary]);
    kicker.attributedStringValue = [[NSAttributedString alloc] initWithString:@"OPTICAL BENCH"
                                                                  attributes:@{NSFontAttributeName: [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold],
                                                                               NSForegroundColorAttributeName: [DSTheme textTertiary],
                                                                               NSKernAttributeName: @1.2}];

    NSTextField *title = DSMakeLabel(@"Double-Slit Lab", [DSTheme uiFontOfSize:22.0 weight:NSFontWeightBold], [DSTheme textPrimary]);
    NSTextField *subtitle = DSMakeLabel(@"Interference & diffraction", [DSTheme uiFontOfSize:11.0 weight:NSFontWeightRegular], [DSTheme textSecondary]);

    [header addSubview:dot];
    [header addSubview:kicker];
    [header addSubview:title];
    [header addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [dot.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [dot.topAnchor constraintEqualToAnchor:kicker.topAnchor constant:2.0],
        [dot.widthAnchor constraintEqualToConstant:8.0],
        [dot.heightAnchor constraintEqualToConstant:8.0],

        [kicker.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:8.0],
        [kicker.topAnchor constraintEqualToAnchor:header.topAnchor],
        [kicker.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor],

        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor],
        [title.topAnchor constraintEqualToAnchor:kicker.bottomAnchor constant:7.0],

        [subtitle.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3.0],
        [subtitle.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],
    ]];
    return header;
}

- (DSLabeledSlider *)makeSliderWithTitle:(NSString *)title min:(double)min max:(double)max value:(double)value logarithmic:(BOOL)log {
    DSLabeledSlider *slider = [[DSLabeledSlider alloc] initWithTitle:title minValue:min maxValue:max value:value];
    slider.logarithmic = log;
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.slider.accessibilityLabel = title;
    [slider.heightAnchor constraintGreaterThanOrEqualToConstant:42.0].active = YES;
    return slider;
}

- (DSLabeledSlider *)wavelengthSlider {
    if (!_wavelengthSlider) {
        _wavelengthSlider = [self makeSliderWithTitle:@"Wavelength" min:380.0 max:780.0 value:self.parameters.wavelengthNm logarithmic:NO];
        _wavelengthSlider.valueFormatter = ^NSString *(double value) {
            return [NSString stringWithFormat:@"%.1f nm", value];
        };
        __weak typeof(self) weakSelf = self;
        _wavelengthSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            [self.parameters applyCustomWavelength:value];
            [self syncWithParameters];
            [self notifyChange];
        };
    }
    return _wavelengthSlider;
}

- (DSLabeledSlider *)linewidthSlider {
    if (!_linewidthSlider) {
        _linewidthSlider = [self makeSliderWithTitle:@"Spectral width (FWHM)" min:0.001 max:300.0 value:self.parameters.spectralWidthNm logarithmic:YES];
        _linewidthSlider.valueFormatter = ^NSString *(double value) {
            if (value < 0.01) return [NSString stringWithFormat:@"%.3f nm", value];
            if (value < 1.0) return [NSString stringWithFormat:@"%.2f nm", value];
            if (value < 10.0) return [NSString stringWithFormat:@"%.1f nm", value];
            return [NSString stringWithFormat:@"%.0f nm", value];
        };
        __weak typeof(self) weakSelf = self;
        _linewidthSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            self.parameters.spectralWidthNm = value;
            [self notifyChange];
        };
    }
    return _linewidthSlider;
}

- (DSLabeledSlider *)sourceDistanceSlider {
    if (!_sourceDistanceSlider) {
        _sourceDistanceSlider = [self makeSliderWithTitle:@"Laser → slits" min:0.10 max:2.00 value:self.parameters.laserDistanceM logarithmic:NO];
        _sourceDistanceSlider.valueFormatter = ^NSString *(double value) {
            return [NSString stringWithFormat:@"%.2f m", value];
        };
        __weak typeof(self) weakSelf = self;
        _sourceDistanceSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            self.parameters.laserDistanceM = value;
            [self notifyChange];
        };
    }
    return _sourceDistanceSlider;
}

- (DSLabeledSlider *)slitCountSlider {
    if (!_slitCountSlider) {
        _slitCountSlider = [self makeSliderWithTitle:@"Number of slits" min:1.0 max:8.0 value:(double)self.parameters.slitCount logarithmic:NO];
        _slitCountSlider.integerValues = YES;
        _slitCountSlider.valueFormatter = ^NSString *(double value) {
            NSInteger count = (NSInteger)llround(value);
            return [NSString stringWithFormat:@"%ld %@", (long)count, count == 1 ? @"slit" : @"slits"];
        };
        __weak typeof(self) weakSelf = self;
        _slitCountSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            self.parameters.slitCount = (NSUInteger)llround(value);
            [self updateDependentControls];
            [self notifyChange];
        };
    }
    return _slitCountSlider;
}

- (DSLabeledSlider *)slitWidthSlider {
    if (!_slitWidthSlider) {
        _slitWidthSlider = [self makeSliderWithTitle:@"Slit width" min:2.0 max:200.0 value:self.parameters.slitWidthUm logarithmic:YES];
        _slitWidthSlider.valueFormatter = ^NSString *(double value) {
            if (value < 10.0) return [NSString stringWithFormat:@"%.1f µm", value];
            return [NSString stringWithFormat:@"%.0f µm", value];
        };
        __weak typeof(self) weakSelf = self;
        _slitWidthSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            self.parameters.slitWidthUm = value;
            [self.parameters clampToValidRange];
            [self updateDependentControls];
            [self notifyChange];
        };
    }
    return _slitWidthSlider;
}

- (DSLabeledSlider *)slitLengthSlider {
    if (!_slitLengthSlider) {
        _slitLengthSlider = [self makeSliderWithTitle:@"Slit length" min:0.10 max:20.0 value:self.parameters.slitLengthMm logarithmic:YES];
        _slitLengthSlider.valueFormatter = ^NSString *(double value) {
            return [NSString stringWithFormat:@"%.2f mm", value];
        };
        __weak typeof(self) weakSelf = self;
        _slitLengthSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            self.parameters.slitLengthMm = value;
            [self notifyChange];
        };
    }
    return _slitLengthSlider;
}

- (DSLabeledSlider *)slitPitchSlider {
    if (!_slitPitchSlider) {
        _slitPitchSlider = [self makeSliderWithTitle:@"Slit pitch" min:20.0 max:2000.0 value:self.parameters.slitPitchUm logarithmic:YES];
        _slitPitchSlider.valueFormatter = ^NSString *(double value) {
            return [NSString stringWithFormat:@"%.0f µm", value];
        };
        __weak typeof(self) weakSelf = self;
        _slitPitchSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            self.parameters.slitPitchUm = value;
            [self.parameters clampToValidRange];
            [self updateDependentControls];
            [self notifyChange];
        };
    }
    return _slitPitchSlider;
}

- (DSLabeledSlider *)screenDistanceSlider {
    if (!_screenDistanceSlider) {
        _screenDistanceSlider = [self makeSliderWithTitle:@"Slits → screen" min:0.20 max:5.00 value:self.parameters.screenDistanceM logarithmic:YES];
        _screenDistanceSlider.valueFormatter = ^NSString *(double value) {
            return [NSString stringWithFormat:@"%.2f m", value];
        };
        __weak typeof(self) weakSelf = self;
        _screenDistanceSlider.onValueChanged = ^(double value) {
            __strong typeof(weakSelf) self = weakSelf;
            self.parameters.screenDistanceM = value;
            [self notifyChange];
        };
    }
    return _screenDistanceSlider;
}

- (NSStackView *)sectionWithTitle:(NSString *)title views:(NSArray<NSView *> *)views {
    NSStackView *section = [[NSStackView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 10.0;

    NSTextField *header = DSMakeLabel(title, [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold], [DSTheme textTertiary]);
    header.attributedStringValue = [[NSAttributedString alloc] initWithString:title
                                                                  attributes:@{NSFontAttributeName: [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold],
                                                                               NSForegroundColorAttributeName: [DSTheme textTertiary],
                                                                               NSKernAttributeName: @1.4}];
    [section addArrangedSubview:header];
    for (NSView *view in views) {
        [section addArrangedSubview:view];
        [view.widthAnchor constraintEqualToAnchor:section.widthAnchor].active = YES;
    }
    return section;
}

- (void)addFullWidthSection:(NSView *)section toStack:(NSStackView *)stack {
    [stack addArrangedSubview:section];
    NSLayoutConstraint *width = [section.widthAnchor constraintEqualToAnchor:stack.widthAnchor];
    width.priority = NSLayoutPriorityRequired;
    width.active = YES;
}

- (NSView *)labeledPopupRow {
    NSStackView *row = [[NSStackView alloc] init];
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    row.spacing = 5.0;
    row.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *label = DSMakeLabel(@"Laser type", [DSTheme uiFontOfSize:11.5 weight:NSFontWeightMedium], [DSTheme textSecondary]);
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    popup.translatesAutoresizingMaskIntoConstraints = NO;
    popup.controlSize = NSControlSizeRegular;
    popup.font = [DSTheme uiFontOfSize:11.5 weight:NSFontWeightRegular];
    [popup addItemsWithTitles:@[
        @"Helium–Neon (633 nm)",
        @"Argon-ion (488 nm)",
        @"DPSS green (532 nm)",
        @"Violet diode (405 nm)",
        @"Red diode (650 nm)",
        @"White light (6500 K)",
        @"Custom colour"
    ]];
    popup.target = self;
    popup.action = @selector(laserTypeChanged:);
    self.laserPopup = popup;
    [row addArrangedSubview:label];
    [row addArrangedSubview:popup];
    [popup.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    return row;
}

- (NSView *)colorRow {
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *label = DSMakeLabel(@"Beam colour", [DSTheme uiFontOfSize:11.5 weight:NSFontWeightMedium], [DSTheme textSecondary]);
    NSColorWell *well = [[NSColorWell alloc] initWithFrame:NSZeroRect];
    well.translatesAutoresizingMaskIntoConstraints = NO;
    well.target = self;
    well.action = @selector(beamColorChanged:);
    well.toolTip = @"Choose a beam colour; it is mapped to the nearest spectral wavelength.";
    well.accessibilityLabel = @"Beam colour";
    if (@available(macOS 13.0, *)) {
        well.colorWellStyle = NSColorWellStyleMinimal;
    }
    self.colorWell = well;
    [row addSubview:label];
    [row addSubview:well];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [well.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [well.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [well.widthAnchor constraintEqualToConstant:35.0],
        [well.heightAnchor constraintEqualToConstant:24.0],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:well.leadingAnchor constant:-8.0],
    ]];
    return row;
}

- (NSView *)coherenceRow {
    NSStackView *row = [[NSStackView alloc] init];
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    row.spacing = 5.0;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *label = DSMakeLabel(@"Coherence", [DSTheme uiFontOfSize:11.5 weight:NSFontWeightMedium], [DSTheme textSecondary]);
    NSSegmentedControl *segmented = [NSSegmentedControl segmentedControlWithLabels:@[@"Coherent", @"Incoherent"]
                                                                     trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                           target:self
                                                                           action:@selector(coherenceChanged:)];
    segmented.translatesAutoresizingMaskIntoConstraints = NO;
    segmented.segmentStyle = NSSegmentStyleRounded;
    segmented.controlSize = NSControlSizeRegular;
    segmented.font = [DSTheme uiFontOfSize:11.0 weight:NSFontWeightMedium];
    self.coherenceControl = segmented;
    [row addArrangedSubview:label];
    [row addArrangedSubview:segmented];
    [segmented.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    return row;
}

- (NSView *)shutterRow {
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *label = DSMakeLabel(@"Laser shutter", [DSTheme uiFontOfSize:11.5 weight:NSFontWeightMedium], [DSTheme textSecondary]);
    NSSwitch *toggle = [[NSSwitch alloc] initWithFrame:NSZeroRect];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.target = self;
    toggle.action = @selector(shutterChanged:);
    toggle.controlSize = NSControlSizeSmall;
    self.shutterSwitch = toggle;
    [row addSubview:label];
    [row addSubview:toggle];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:24.0],
    ]];
    return row;
}

- (NSTextField *)noteLabel:(NSString *)text {
    NSTextField *label = DSMakeLabel(text, [DSTheme uiFontOfSize:9.5 weight:NSFontWeightRegular], [DSTheme textTertiary]);
    label.maximumNumberOfLines = 3;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSView *)separator {
    DSSeparatorView *view = [[DSSeparatorView alloc] initWithFrame:NSZeroRect];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [view.heightAnchor constraintEqualToConstant:1.0].active = YES;
    return view;
}

#pragma mark - Actions

- (void)laserTypeChanged:(NSPopUpButton *)sender {
    NSInteger index = sender.indexOfSelectedItem;
    [self.parameters applyLaserPreset:(DSLaserPreset)index];
    [self syncWithParameters];
    [self notifyChange];
}

- (void)coherenceChanged:(NSSegmentedControl *)sender {
    self.parameters.coherenceMode = sender.selectedSegment == 0 ? DSCoherenceModeCoherent : DSCoherenceModeIncoherent;
    [self notifyChange];
}

- (void)beamColorChanged:(NSColorWell *)sender {
    [self.parameters applyBeamColor:sender.color];
    [self syncWithParameters];
    [self notifyChange];
}

- (void)shutterChanged:(NSSwitch *)sender {
    self.parameters.shutterOpen = sender.state == NSControlStateValueOn;
    [self notifyChange];
}

- (void)resetExperiment {
    DSExperimentParameters *defaults = [DSExperimentParameters defaultParameters];
    self.parameters.laserPreset = defaults.laserPreset;
    self.parameters.coherenceMode = defaults.coherenceMode;
    self.parameters.wavelengthNm = defaults.wavelengthNm;
    self.parameters.spectralWidthNm = defaults.spectralWidthNm;
    self.parameters.laserDistanceM = defaults.laserDistanceM;
    self.parameters.slitCount = defaults.slitCount;
    self.parameters.slitWidthUm = defaults.slitWidthUm;
    self.parameters.slitLengthMm = defaults.slitLengthMm;
    self.parameters.slitPitchUm = defaults.slitPitchUm;
    self.parameters.screenDistanceM = defaults.screenDistanceM;
    self.parameters.shutterOpen = YES;
    self.parameters.beamColor = defaults.beamColor;
    [self.parameters clampToValidRange];
    [self syncWithParameters];
    [self notifyChange];
}

- (void)syncWithParameters {
    if (!self.isViewLoaded) {
        return;
    }
    [self.parameters clampToValidRange];
    [self.laserPopup selectItemAtIndex:(NSInteger)self.parameters.laserPreset];
    [self.coherenceControl setSelectedSegment:self.parameters.coherenceMode == DSCoherenceModeCoherent ? 0 : 1];
    [self.colorWell setColor:self.parameters.beamColor];
    self.laserSwatch.layer.backgroundColor = self.parameters.beamColor.CGColor;
    [self.wavelengthSlider setValue:self.parameters.wavelengthNm];
    [self.linewidthSlider setValue:self.parameters.spectralWidthNm];
    [self.sourceDistanceSlider setValue:self.parameters.laserDistanceM];
    [self.slitCountSlider setValue:(double)self.parameters.slitCount];
    [self.slitWidthSlider setValue:self.parameters.slitWidthUm];
    [self.slitLengthSlider setValue:self.parameters.slitLengthMm];
    [self.slitPitchSlider setValue:self.parameters.slitPitchUm];
    [self.screenDistanceSlider setValue:self.parameters.screenDistanceM];
    self.shutterSwitch.state = self.parameters.shutterOpen ? NSControlStateValueOn : NSControlStateValueOff;
    [self updateDependentControls];
}

- (void)updateDependentControls {
    [self.slitPitchSlider setValue:self.parameters.slitPitchUm];
    BOOL multiple = self.parameters.slitCount > 1;
    self.slitPitchSlider.slider.enabled = multiple;
    self.slitPitchSlider.alphaValue = multiple ? 1.0 : 0.4;
    self.slitPitchSlider.toolTip = multiple ? @"Centre-to-centre distance between adjacent slits." : @"Pitch is only relevant with two or more slits.";

    BOOL white = [self.parameters isWhiteLight];
    self.wavelengthSlider.slider.enabled = !white;
    self.wavelengthSlider.alphaValue = white ? 0.55 : 1.0;
    self.wavelengthSlider.toolTip = white ? @"White light spans the visible spectrum; choose a custom source to set a single wavelength." : @"Vacuum wavelength of the source.";
    if (white) {
        self.wavelengthSlider.valueLabel.stringValue = @"Visible";
    } else {
        [self.wavelengthSlider setValue:self.parameters.wavelengthNm];
    }

    self.linewidthSlider.slider.enabled = !white;
    self.linewidthSlider.alphaValue = white ? 0.55 : 1.0;
    self.linewidthSlider.toolTip = white ? @"White light uses a 6500 K broadband spectrum." : @"FWHM of the source spectrum; broader spectra reduce fringe visibility.";
    if (white) {
        self.linewidthSlider.valueLabel.stringValue = @"Broadband";
    } else {
        [self.linewidthSlider setValue:self.parameters.spectralWidthNm];
    }
    self.colorWell.enabled = YES;
}

- (void)notifyChange {
    [self.parameters clampToValidRange];
    if (self.onParametersChanged) {
        self.onParametersChanged();
    }
}

@end
