#import "DSResultsViewController.h"
#import "DSExperimentParameters.h"
#import "DSPhysicsEngine.h"
#import "DSPatternView.h"
#import "DSTheme.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NSString *DSFormatLengthMM(double millimeters) {
    if (millimeters <= 0.0 || !isfinite(millimeters)) {
        return @"—";
    }
    double abs = fabs(millimeters);
    if (abs >= 1000.0) {
        return [NSString stringWithFormat:@"%.2f m", millimeters / 1000.0];
    }
    if (abs >= 10.0) {
        return [NSString stringWithFormat:@"%.1f mm", millimeters];
    }
    if (abs >= 1.0) {
        return [NSString stringWithFormat:@"%.2f mm", millimeters];
    }
    if (abs >= 0.05) {
        return [NSString stringWithFormat:@"%.0f µm", millimeters * 1000.0];
    }
    if (abs >= 0.001) {
        return [NSString stringWithFormat:@"%.1f µm", millimeters * 1000.0];
    }
    return [NSString stringWithFormat:@"%.0f nm", millimeters * 1e6];
}

static NSString *DSFormatLinewidth(double nm, BOOL white) {
    if (white) {
        return @"Broadband";
    }
    if (nm < 0.01) return [NSString stringWithFormat:@"%.3f nm", nm];
    if (nm < 1.0) return [NSString stringWithFormat:@"%.2f nm", nm];
    if (nm < 10.0) return [NSString stringWithFormat:@"%.1f nm", nm];
    return [NSString stringWithFormat:@"%.0f nm", nm];
}

@interface DSResultsViewController ()
@property (nonatomic, strong) DSExperimentParameters *parameters;
@property (nonatomic, strong, readwrite, nullable) NSImage *currentImage;
@property (nonatomic, strong) DSPatternView *patternView;
@property (nonatomic, strong) DSProfileView *profileView;
@property (nonatomic, strong) NSTextField *kickerLabel;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *subtitleLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *rangeCaption;
@property (nonatomic, strong) NSTextField *chartSubtitleLabel;
@property (nonatomic, strong) NSView *accentDot;
@property (nonatomic, strong) NSView *accentRule;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSTextField *> *statLabels;
@property (nonatomic) BOOL shutterClosed;
@property (nonatomic, assign) double displayXHalfRangeMm;
@property (nonatomic, assign) double displayYHalfRangeMm;
@property (nonatomic, assign) double lockedDisplayXHalfRangeMm;
@property (nonatomic, assign) double lockedDisplayYHalfRangeMm;
@end

@implementation DSResultsViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _parameters = [DSExperimentParameters defaultParameters];
        _statLabels = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 370.0, 900.0)];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [DSTheme background].CGColor;
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

    DSFlippedView *documentView = [[DSFlippedView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 370.0, 900.0)];
    documentView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = documentView;

    NSStackView *stack = [[NSStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.distribution = NSStackViewDistributionFill;
    stack.spacing = 14.0;
    [documentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [documentView.leadingAnchor constraintEqualToAnchor:scrollView.contentView.leadingAnchor],
        [documentView.topAnchor constraintEqualToAnchor:scrollView.contentView.topAnchor],
        [documentView.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor],

        [stack.leadingAnchor constraintEqualToAnchor:documentView.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:documentView.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:documentView.topAnchor constant:20.0],
        [stack.bottomAnchor constraintEqualToAnchor:documentView.bottomAnchor constant:-24.0],
    ]];

    NSView *header = [self buildHeader];
    [stack addArrangedSubview:header];
    [header.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    DSCardView *patternCard = [[DSCardView alloc] initWithFrame:NSZeroRect];
    patternCard.translatesAutoresizingMaskIntoConstraints = NO;
    patternCard.cornerRadius = 12.0;
    self.patternView = [[DSPatternView alloc] initWithFrame:NSZeroRect];
    self.patternView.translatesAutoresizingMaskIntoConstraints = NO;
    [patternCard addSubview:self.patternView];
    [NSLayoutConstraint activateConstraints:@[
        [self.patternView.leadingAnchor constraintEqualToAnchor:patternCard.leadingAnchor constant:10.0],
        [self.patternView.trailingAnchor constraintEqualToAnchor:patternCard.trailingAnchor constant:-10.0],
        [self.patternView.topAnchor constraintEqualToAnchor:patternCard.topAnchor constant:10.0],
        [self.patternView.bottomAnchor constraintEqualToAnchor:patternCard.bottomAnchor constant:-10.0],
        [self.patternView.heightAnchor constraintEqualToAnchor:self.patternView.widthAnchor multiplier:0.6],
    ]];
    [stack addArrangedSubview:patternCard];
    [patternCard.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [stack setCustomSpacing:6.0 afterView:patternCard];

    self.rangeCaption = DSMakeLabel(@"",
                                    [DSTheme uiFontOfSize:9.5 weight:NSFontWeightRegular],
                                    [DSTheme textTertiary]);
    self.rangeCaption.maximumNumberOfLines = 2;
    self.rangeCaption.lineBreakMode = NSLineBreakByWordWrapping;
    [stack addArrangedSubview:self.rangeCaption];
    [self.rangeCaption.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    DSCardView *chartCard = [self buildChartCard];
    [stack addArrangedSubview:chartCard];
    [chartCard.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    DSCardView *statsCard = [self buildStatsCard];
    [stack addArrangedSubview:statsCard];
    [statsCard.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    NSButton *saveButton = [NSButton buttonWithTitle:@"Save Pattern…"
                                              image:[NSImage imageWithSystemSymbolName:@"square.and.arrow.down"
                                                                             accessibilityDescription:@"Save pattern"]
                                             target:self
                                             action:@selector(savePattern:)];
    saveButton.imagePosition = NSImageLeading;
    saveButton.bezelStyle = NSBezelStyleRounded;
    saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:saveButton];
    [saveButton.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    NSTextField *note = DSMakeLabel(@"Fraunhofer far-field model · scalar diffraction · λ-dependent dispersion included",
                                     [DSTheme uiFontOfSize:9.0 weight:NSFontWeightRegular],
                                     [DSTheme textTertiary]);
    note.maximumNumberOfLines = 2;
    note.lineBreakMode = NSLineBreakByWordWrapping;
    [stack addArrangedSubview:note];
    [note.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    [self updateWithParameters:self.parameters result:nil];
}

- (NSView *)buildHeader {
    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;

    self.accentDot = [[NSView alloc] initWithFrame:NSZeroRect];
    self.accentDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentDot.wantsLayer = YES;
    self.accentDot.layer.cornerRadius = 4.0;
    self.accentDot.layer.backgroundColor = self.parameters.beamColor.CGColor;

    self.kickerLabel = DSMakeLabel(@"DETECTOR SCREEN", [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold], [DSTheme textTertiary]);
    self.kickerLabel.attributedStringValue = [[NSAttributedString alloc] initWithString:@"DETECTOR SCREEN"
                                                                             attributes:@{NSFontAttributeName: [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold],
                                                                                          NSForegroundColorAttributeName: [DSTheme textTertiary],
                                                                                          NSKernAttributeName: @1.2}];
    self.statusLabel = DSMakeLabel(@"● LIVE", [DSTheme monoFontOfSize:9.0 weight:NSFontWeightSemibold], [DSTheme liveGreen]);
    self.statusLabel.alignment = NSTextAlignmentRight;

    self.titleLabel = DSMakeLabel(@"Detection pattern", [DSTheme uiFontOfSize:22.0 weight:NSFontWeightBold], [DSTheme textPrimary]);
    self.subtitleLabel = DSMakeLabel(@"", [DSTheme uiFontOfSize:11.0 weight:NSFontWeightRegular], [DSTheme textSecondary]);

    self.accentRule = [[NSView alloc] initWithFrame:NSZeroRect];
    self.accentRule.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentRule.wantsLayer = YES;
    self.accentRule.layer.cornerRadius = 1.0;
    self.accentRule.layer.backgroundColor = self.parameters.beamColor.CGColor;

    [header addSubview:self.accentDot];
    [header addSubview:self.kickerLabel];
    [header addSubview:self.statusLabel];
    [header addSubview:self.titleLabel];
    [header addSubview:self.subtitleLabel];
    [header addSubview:self.accentRule];

    [NSLayoutConstraint activateConstraints:@[
        [self.accentDot.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [self.accentDot.topAnchor constraintEqualToAnchor:self.kickerLabel.topAnchor constant:2.0],
        [self.accentDot.widthAnchor constraintEqualToConstant:8.0],
        [self.accentDot.heightAnchor constraintEqualToConstant:8.0],

        [self.kickerLabel.leadingAnchor constraintEqualToAnchor:self.accentDot.trailingAnchor constant:8.0],
        [self.kickerLabel.topAnchor constraintEqualToAnchor:header.topAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.kickerLabel.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.kickerLabel.trailingAnchor constant:8.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.kickerLabel.bottomAnchor constant:8.0],

        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor],
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3.0],

        [self.accentRule.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [self.accentRule.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:11.0],
        [self.accentRule.widthAnchor constraintEqualToConstant:44.0],
        [self.accentRule.heightAnchor constraintEqualToConstant:2.0],
        [self.accentRule.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],
    ]];
    return header;
}


- (DSCardView *)buildChartCard {
    DSCardView *card = [[DSCardView alloc] initWithFrame:NSZeroRect];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *title = DSMakeLabel(@"INTENSITY PROFILE", [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold], [DSTheme textTertiary]);
    title.attributedStringValue = [[NSAttributedString alloc] initWithString:@"INTENSITY PROFILE"
                                                                  attributes:@{NSFontAttributeName: [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold],
                                                                               NSForegroundColorAttributeName: [DSTheme textTertiary],
                                                                               NSKernAttributeName: @1.1}];
    NSTextField *subtitle = DSMakeLabel(@"horizontal cross-section · x in mm", [DSTheme uiFontOfSize:9.5 weight:NSFontWeightRegular], [DSTheme textTertiary]);
    self.chartSubtitleLabel = subtitle;
    self.profileView = [[DSProfileView alloc] initWithFrame:NSZeroRect];
    self.profileView.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:title];
    [card addSubview:subtitle];
    [card addSubview:self.profileView];
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [subtitle.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [subtitle.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [subtitle.leadingAnchor constraintGreaterThanOrEqualToAnchor:title.trailingAnchor constant:8.0],
        [self.profileView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8.0],
        [self.profileView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8.0],
        [self.profileView.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8.0],
        [self.profileView.heightAnchor constraintEqualToConstant:148.0],
        [self.profileView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10.0],
    ]];
    return card;
}

- (DSCardView *)buildStatsCard {
    DSCardView *card = [[DSCardView alloc] initWithFrame:NSZeroRect];
    card.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *title = DSMakeLabel(@"MEASUREMENTS", [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold], [DSTheme textTertiary]);
    title.attributedStringValue = [[NSAttributedString alloc] initWithString:@"MEASUREMENTS"
                                                                  attributes:@{NSFontAttributeName: [DSTheme uiFontOfSize:9.5 weight:NSFontWeightSemibold],
                                                                               NSForegroundColorAttributeName: [DSTheme textTertiary],
                                                                               NSKernAttributeName: @1.1}];

    NSStackView *rows = [[NSStackView alloc] init];
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    rows.orientation = NSUserInterfaceLayoutOrientationVertical;
    rows.alignment = NSLayoutAttributeLeading;
    rows.spacing = 4.0;

    NSArray<NSArray<NSString *> *> *specs = @[
        @[@"Source", @"source"],
        @[@"Mode", @"mode"],
        @[@"Linewidth", @"linewidth"],
        @[@"Fringe spacing", @"fringe"],
        @[@"Central lobe", @"lobe"],
        @[@"Vertical lobe", @"vertical"],
        @[@"Visibility", @"visibility"],
        @[@"Coherence length", @"coherence"],
        @[@"Aperture", @"aperture"],
        @[@"Slit pitch", @"pitch"],
    ];
    for (NSArray<NSString *> *spec in specs) {
        NSView *row = [self statRowWithTitle:spec[0] key:spec[1]];
        [rows addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:rows.widthAnchor].active = YES;
    }

    [card addSubview:title];
    [card addSubview:rows];
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-14.0],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [rows.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10.0],
        [rows.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-13.0],
    ]];
    return card;
}

- (NSView *)statRowWithTitle:(NSString *)title key:(NSString *)key {
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *name = DSMakeLabel(title, [DSTheme uiFontOfSize:10.5 weight:NSFontWeightRegular], [DSTheme textSecondary]);
    NSTextField *value = DSMakeLabel(@"—", [DSTheme monoFontOfSize:10.0 weight:NSFontWeightMedium], [DSTheme textPrimary]);
    value.alignment = NSTextAlignmentRight;
    value.lineBreakMode = NSLineBreakByTruncatingTail;
    value.toolTip = title;
    [row addSubview:name];
    [row addSubview:value];
    [NSLayoutConstraint activateConstraints:@[
        [name.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [name.topAnchor constraintEqualToAnchor:row.topAnchor],
        [name.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [value.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [value.centerYAnchor constraintEqualToAnchor:name.centerYAnchor],
        [value.leadingAnchor constraintGreaterThanOrEqualToAnchor:name.trailingAnchor constant:10.0],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:16.0],
    ]];
    self.statLabels[key] = value;
    return row;
}

#pragma mark - Updates

- (void)updateWithParameters:(DSExperimentParameters *)parameters result:(DSPatternResult *)result {
    if (parameters) {
        self.parameters = parameters;
    }
    if (!self.isViewLoaded) {
        return;
    }

    NSColor *accent = self.parameters.beamColor ?: [NSColor whiteColor];
    self.accentDot.layer.backgroundColor = accent.CGColor;
    self.accentRule.layer.backgroundColor = accent.CGColor;
    self.patternView.accentColor = accent;
    self.profileView.accentColor = accent;
    self.titleLabel.textColor = [DSTheme textPrimary];

    NSString *subtitle = [NSString stringWithFormat:@"%@ · %@ · %lu %@",
                          self.parameters.laserPresetShortName,
                          self.parameters.coherenceMode == DSCoherenceModeCoherent ? @"Coherent" : @"Incoherent",
                          (unsigned long)self.parameters.slitCount,
                          self.parameters.slitCount == 1 ? @"slit" : @"slits"];
    self.subtitleLabel.stringValue = subtitle;

    if (result) {
        self.currentImage = result.image;
        self.patternView.patternImage = result.image;
        self.patternView.xHalfRangeMm = result.metrics.xHalfRangeMm;
        self.patternView.yHalfRangeMm = result.metrics.yHalfRangeMm;
        self.displayXHalfRangeMm = self.lockedDisplayXHalfRangeMm > 0.0 ? self.lockedDisplayXHalfRangeMm : result.metrics.xHalfRangeMm;
        self.displayYHalfRangeMm = self.lockedDisplayYHalfRangeMm > 0.0 ? self.lockedDisplayYHalfRangeMm : result.metrics.yHalfRangeMm;
        [self.profileView setProfileData:result.profile
                                   count:result.profileLength
                            xHalfRangeMm:result.metrics.xHalfRangeMm
                             accentColor:accent];
        NSString *axisUnit = result.metrics.xHalfRangeMm < 1.0 ? @"µm" : @"mm";
        self.chartSubtitleLabel.stringValue = [NSString stringWithFormat:@"horizontal cross-section · x in %@", axisUnit];
    }

    self.statLabels[@"source"].stringValue = [self.parameters isWhiteLight] ? @"White light" : self.parameters.laserPresetShortName;
    self.statLabels[@"mode"].stringValue = self.parameters.coherenceMode == DSCoherenceModeCoherent ? @"Coherent" : @"Incoherent";
    self.statLabels[@"linewidth"].stringValue = DSFormatLinewidth(self.parameters.spectralWidthNm, [self.parameters isWhiteLight]);
    self.statLabels[@"fringe"].stringValue = (result && result.metrics.fringeSpacingMm > 0.0) ? DSFormatLengthMM(result.metrics.fringeSpacingMm) : @"—";
    self.statLabels[@"lobe"].stringValue = result ? DSFormatLengthMM(result.metrics.centralLobeWidthMm) : @"—";
    self.statLabels[@"vertical"].stringValue = result ? DSFormatLengthMM(result.metrics.verticalLobeHeightMm) : @"—";
    if (result) {
        double percent = result.metrics.visibility * 100.0;
        self.statLabels[@"visibility"].stringValue = percent >= 10.0 ? [NSString stringWithFormat:@"%.0f %%", percent]
                                                                     : [NSString stringWithFormat:@"%.1f %%", percent];
    } else {
        self.statLabels[@"visibility"].stringValue = @"—";
    }
    self.statLabels[@"coherence"].stringValue = result ? DSFormatLengthMM(result.metrics.coherenceLengthMm) : @"—";
    self.statLabels[@"aperture"].stringValue = [NSString stringWithFormat:@"%lu × %.0f µm · %.2f mm",
                                                (unsigned long)self.parameters.slitCount,
                                                self.parameters.slitWidthUm,
                                                self.parameters.slitLengthMm];
    self.statLabels[@"pitch"].stringValue = self.parameters.slitCount > 1
        ? [NSString stringWithFormat:@"%.0f µm", self.parameters.slitPitchUm]
        : @"—";

    [self updateScaleCaption];
    [self updateStatus];
}

- (void)updateScaleCaption {
    if (!self.isViewLoaded) {
        return;
    }
    if (self.displayXHalfRangeMm <= 0.0) {
        self.rangeCaption.stringValue = @"Detector scale: fixed · preparing the first render.";
        return;
    }
    NSString *field = [NSString stringWithFormat:@"Detector field ±%@ × ±%@",
                       DSFormatLengthMM(self.displayXHalfRangeMm),
                       DSFormatLengthMM(self.displayYHalfRangeMm)];
    self.rangeCaption.stringValue = [field stringByAppendingString:@" · fixed scale. Fringes spread with screen distance."];
}

- (void)setShutterClosed:(BOOL)closed {
    _shutterClosed = closed;
    [self updateStatus];
}

- (void)updateStatus {
    self.patternView.shutterClosed = self.shutterClosed;
    if (self.shutterClosed) {
        self.statusLabel.attributedStringValue = [[NSAttributedString alloc] initWithString:@"● SHUTTER CLOSED"
                                                                                 attributes:@{NSFontAttributeName: [DSTheme monoFontOfSize:9.0 weight:NSFontWeightSemibold],
                                                                                              NSForegroundColorAttributeName: [DSTheme warning]}];
    } else {
        self.statusLabel.attributedStringValue = [[NSAttributedString alloc] initWithString:@"● LIVE"
                                                                                 attributes:@{NSFontAttributeName: [DSTheme monoFontOfSize:9.0 weight:NSFontWeightSemibold],
                                                                                              NSForegroundColorAttributeName: [DSTheme liveGreen]}];
    }
}

#pragma mark - Export

- (void)savePattern:(id)sender {
    if (!self.currentImage) {
        NSBeep();
        return;
    }
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"Save Detector Pattern";
    panel.nameFieldStringValue = @"double-slit-pattern.png";
    panel.allowedContentTypes = @[UTTypePNG];
    panel.canCreateDirectories = YES;
    NSWindow *window = self.view.window;
    void (^completion)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) {
            return;
        }
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[self.currentImage TIFFRepresentation]];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSError *error = nil;
        BOOL ok = png && [png writeToURL:panel.URL options:NSDataWritingAtomic error:&error];
        if (!ok) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Could not save the pattern";
            alert.informativeText = error.localizedDescription ?: @"Unknown error.";
            alert.alertStyle = NSAlertStyleWarning;
            [alert runModal];
        }
    };
    if (window) {
        [panel beginSheetModalForWindow:window completionHandler:completion];
    } else {
        completion([panel runModal]);
    }
}

- (void)getCurrentDisplayRangeXHalfMm:(double *)xHalfRangeMm yHalfMm:(double *)yHalfRangeMm {
    if (xHalfRangeMm) *xHalfRangeMm = self.displayXHalfRangeMm;
    if (yHalfRangeMm) *yHalfRangeMm = self.displayYHalfRangeMm;
}

- (void)setLockedDisplayRangeXHalfMm:(double)xHalfRangeMm yHalfMm:(double)yHalfRangeMm {
    self.lockedDisplayXHalfRangeMm = xHalfRangeMm;
    self.lockedDisplayYHalfRangeMm = yHalfRangeMm;
    self.displayXHalfRangeMm = xHalfRangeMm;
    self.displayYHalfRangeMm = yHalfRangeMm;
    [self updateScaleCaption];
}

- (BOOL)isDetectorScaleLocked {
    return YES;
}

@end
