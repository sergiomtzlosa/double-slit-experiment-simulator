#import "DSStageViewController.h"
#import "DSSceneController.h"
#import "DSExperimentParameters.h"
#import "DSTheme.h"
#import <SceneKit/SceneKit.h>
#import <QuartzCore/QuartzCore.h>

@interface DSStageViewController ()
@property (nonatomic, strong) SCNView *sceneView;
@property (nonatomic, strong) DSSceneController *sceneController;
@property (nonatomic, strong) NSVisualEffectView *infoCard;
@property (nonatomic, strong) NSTextField *infoSubtitle;
@property (nonatomic, strong) NSButton *labelsButton;
@property (nonatomic, strong) NSImage *pendingImage;
@property (nonatomic) BOOL labelsVisible;
@end

@interface DSPassthroughVisualEffectView : NSVisualEffectView
@end

@implementation DSPassthroughVisualEffectView
- (NSView *)hitTest:(NSPoint)point {
    return nil;
}
@end

@implementation DSStageViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _labelsVisible = YES;
    }
    return self;
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 760.0, 900.0)];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [DSTheme background].CGColor;
    self.view = root;

    SCNView *sceneView = [[SCNView alloc] initWithFrame:NSZeroRect];
    sceneView.translatesAutoresizingMaskIntoConstraints = NO;
    sceneView.allowsCameraControl = YES;
    sceneView.autoenablesDefaultLighting = NO;
    sceneView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    [root addSubview:sceneView];
    self.sceneView = sceneView;
    [NSLayoutConstraint activateConstraints:@[
        [sceneView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [sceneView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [sceneView.topAnchor constraintEqualToAnchor:root.topAnchor],
        [sceneView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
    ]];
    self.sceneController = [[DSSceneController alloc] initWithSceneView:sceneView];

    [self buildOverlaysInRoot:root];

    if (self.pendingImage) {
        [self.sceneController setPatternImage:self.pendingImage];
        self.pendingImage = nil;
    }
    [self.sceneController setLabelsVisible:self.labelsVisible];
}

- (NSImage *)stageSymbolNamed:(NSString *)symbol color:(NSColor *)color {
    NSImageSymbolConfiguration *base = [NSImageSymbolConfiguration configurationWithPointSize:11.5
                                                                                       weight:NSFontWeightMedium];
    NSImage *image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:symbol]
                      imageWithSymbolConfiguration:base];
    NSImageSymbolConfiguration *palette = [NSImageSymbolConfiguration configurationWithPaletteColors:@[color]];
    NSImage *tinted = [image imageWithSymbolConfiguration:palette];
    tinted.template = NO;
    return tinted;
}

- (NSButton *)stageButtonWithTitle:(NSString *)title
                            symbol:(NSString *)symbol
                           tooltip:(NSString *)tooltip
                            action:(SEL)action {
    NSImage *image = [self stageSymbolNamed:symbol color:[DSTheme textPrimary]];
    NSButton *button = [NSButton buttonWithTitle:title image:image target:self action:action];
    button.imagePosition = NSImageLeading;
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.controlSize = NSControlSizeSmall;
    button.font = [DSTheme uiFontOfSize:10.5 weight:NSFontWeightMedium];
    button.toolTip = tooltip;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintEqualToConstant:26.0].active = YES;
    return button;
}

- (void)updateLabelsButtonAppearance {
    BOOL visible = self.labelsVisible;
    self.labelsButton.state = visible ? NSControlStateValueOn : NSControlStateValueOff;
    NSString *symbol = visible ? @"eye" : @"eye.slash";
    NSColor *color = visible ? [DSTheme textPrimary] : [DSTheme textSecondary];
    self.labelsButton.image = [self stageSymbolNamed:symbol color:color];
    self.labelsButton.toolTip = visible ? @"Hide the measurement labels in the 3D scene (⌘L)"
                                        : @"Show the measurement labels in the 3D scene (⌘L)";
}
- (NSVisualEffectView *)overlayViewWithMaterial:(NSVisualEffectMaterial)material passthrough:(BOOL)passthrough {
    NSVisualEffectView *view = passthrough ? [[DSPassthroughVisualEffectView alloc] initWithFrame:NSZeroRect]
                                           : [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.material = material;
    view.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    view.state = NSVisualEffectStateActive;
    view.wantsLayer = YES;
    view.layer.cornerRadius = 10.0;
    view.layer.masksToBounds = YES;
    return view;
}

- (void)buildOverlaysInRoot:(NSView *)root {
    NSVisualEffectView *infoCard = [self overlayViewWithMaterial:NSVisualEffectMaterialHUDWindow passthrough:YES];
    self.infoCard = infoCard;
    [root addSubview:infoCard];

    NSTextField *kicker = DSMakeLabel(@"3D EXPERIMENT", [DSTheme uiFontOfSize:9.0 weight:NSFontWeightSemibold], [DSTheme textTertiary]);
    kicker.attributedStringValue = [[NSAttributedString alloc] initWithString:@"3D EXPERIMENT"
                                                                  attributes:@{NSFontAttributeName: [DSTheme uiFontOfSize:9.0 weight:NSFontWeightSemibold],
                                                                               NSForegroundColorAttributeName: [DSTheme textTertiary],
                                                                               NSKernAttributeName: @1.2}];
    NSTextField *title = DSMakeLabel(@"Optical bench", [DSTheme uiFontOfSize:14.0 weight:NSFontWeightSemibold], [DSTheme textPrimary]);
    NSTextField *subtitle = DSMakeLabel(@"Fraunhofer far field", [DSTheme uiFontOfSize:10.0 weight:NSFontWeightRegular], [DSTheme textSecondary]);
    self.infoSubtitle = subtitle;

    [infoCard addSubview:kicker];
    [infoCard addSubview:title];
    [infoCard addSubview:subtitle];
    [NSLayoutConstraint activateConstraints:@[
        [kicker.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:12.0],
        [kicker.topAnchor constraintEqualToAnchor:infoCard.topAnchor constant:10.0],
        [kicker.trailingAnchor constraintLessThanOrEqualToAnchor:infoCard.trailingAnchor constant:-12.0],
        [title.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:12.0],
        [title.topAnchor constraintEqualToAnchor:kicker.bottomAnchor constant:3.0],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:infoCard.trailingAnchor constant:-12.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:infoCard.leadingAnchor constant:12.0],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2.0],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:infoCard.trailingAnchor constant:-12.0],
        [subtitle.bottomAnchor constraintEqualToAnchor:infoCard.bottomAnchor constant:-10.0],
    ]];

    NSVisualEffectView *buttonsCard = [self overlayViewWithMaterial:NSVisualEffectMaterialHUDWindow passthrough:NO];
    [root addSubview:buttonsCard];
    NSStackView *buttonRow = [[NSStackView alloc] init];
    buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
    buttonRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonRow.spacing = 6.0;
    buttonRow.alignment = NSLayoutAttributeCenterY;
    [buttonsCard addSubview:buttonRow];

    NSButton *resetButton = [self stageButtonWithTitle:@"Reset view"
                                                symbol:@"arrow.counterclockwise"
                                               tooltip:@"Reset the 3D setup camera to default position (⌘0)"
                                                action:@selector(resetCamera)];
    [buttonRow addArrangedSubview:resetButton];

    NSButton *labelsButton = [self stageButtonWithTitle:@"3D labels"
                                                symbol:@"eye"
                                               tooltip:@"Show or hide the measurement labels in the 3D scene (⌘L)"
                                                action:@selector(toggleLabels)];
    labelsButton.buttonType = NSButtonTypeToggle;
    self.labelsButton = labelsButton;

    [buttonRow addArrangedSubview:labelsButton];
    [self updateLabelsButtonAppearance];
    [NSLayoutConstraint activateConstraints:@[
        [buttonRow.leadingAnchor constraintEqualToAnchor:buttonsCard.leadingAnchor constant:4.0],
        [buttonRow.trailingAnchor constraintEqualToAnchor:buttonsCard.trailingAnchor constant:-4.0],
        [buttonRow.topAnchor constraintEqualToAnchor:buttonsCard.topAnchor constant:4.0],
        [buttonRow.bottomAnchor constraintEqualToAnchor:buttonsCard.bottomAnchor constant:-4.0],
    ]];

    NSVisualEffectView *hintCard = [self overlayViewWithMaterial:NSVisualEffectMaterialHUDWindow passthrough:YES];
    [root addSubview:hintCard];
    NSTextField *hint = DSMakeLabel(@"Drag to orbit  ·  Scroll to zoom  ·  Aperture enlarged for clarity",
                                    [DSTheme uiFontOfSize:9.5 weight:NSFontWeightRegular],
                                    [DSTheme textSecondary]);
    [hintCard addSubview:hint];
    [NSLayoutConstraint activateConstraints:@[
        [hint.leadingAnchor constraintEqualToAnchor:hintCard.leadingAnchor constant:10.0],
        [hint.trailingAnchor constraintEqualToAnchor:hintCard.trailingAnchor constant:-10.0],
        [hint.topAnchor constraintEqualToAnchor:hintCard.topAnchor constant:7.0],
        [hint.bottomAnchor constraintEqualToAnchor:hintCard.bottomAnchor constant:-7.0],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [infoCard.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16.0],
        [infoCard.topAnchor constraintEqualToAnchor:root.topAnchor constant:16.0],
        [infoCard.widthAnchor constraintGreaterThanOrEqualToConstant:190.0],
        [infoCard.widthAnchor constraintLessThanOrEqualToConstant:330.0],

        [buttonsCard.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16.0],
        [buttonsCard.topAnchor constraintEqualToAnchor:root.topAnchor constant:16.0],

        [hintCard.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16.0],
        [hintCard.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-16.0],
        [hintCard.trailingAnchor constraintLessThanOrEqualToAnchor:root.trailingAnchor constant:-16.0],
    ]];
}

#pragma mark - Public

- (void)applyParameters:(DSExperimentParameters *)parameters {
    (void)self.view;
    [self.sceneController applyParameters:parameters];
    NSString *coherence = parameters.coherenceMode == DSCoherenceModeCoherent ? @"coherent" : @"incoherent";
    self.infoSubtitle.stringValue = [NSString stringWithFormat:@"%@ · %@ · %lu %@",
                                     parameters.laserPresetShortName,
                                     coherence,
                                     (unsigned long)parameters.slitCount,
                                     parameters.slitCount == 1 ? @"slit" : @"slits"];
    [self setShutterOpen:parameters.shutterOpen];
}

- (void)setPatternImage:(NSImage *)image {
    self.pendingImage = image;
    if (!self.isViewLoaded) {
        return;
    }
    [self.sceneController setPatternImage:image];
    self.pendingImage = nil;
}

- (void)setShutterOpen:(BOOL)open {
    if (!self.isViewLoaded) {
        return;
    }
    [self.sceneController setShutterOpen:open];
}

- (void)resetCamera {
    if (!self.isViewLoaded) {
        return;
    }
    [self.sceneController resetCamera];
}

- (void)toggleLabels {
    self.labelsVisible = !self.labelsVisible;
    if (self.isViewLoaded) {
        [self.sceneController setLabelsVisible:self.labelsVisible];
        [self updateLabelsButtonAppearance];
    }
}

@end
