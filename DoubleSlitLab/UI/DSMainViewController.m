#import "DSMainViewController.h"
#import "DSExperimentParameters.h"
#import "DSLabConfiguration.h"
#import "DSPhysicsEngine.h"
#import "DSControlsViewController.h"
#import "DSStageViewController.h"
#import "DSResultsViewController.h"
#import "DSTheme.h"
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface DSMainViewController ()
@property (nonatomic, strong) DSExperimentParameters *parameters;
@property (nonatomic, strong) DSControlsViewController *controlsViewController;
@property (nonatomic, strong) DSStageViewController *stageViewController;
@property (nonatomic, strong) DSResultsViewController *resultsViewController;
@property (nonatomic, strong) dispatch_queue_t renderQueue;
@property (nonatomic, strong) DSPatternResult *currentPattern;
@property (nonatomic) BOOL renderInFlight;
@property (nonatomic) BOOL renderPending;
@property (nonatomic) uint64_t renderGeneration;
@property (nonatomic) BOOL didConfigureInitialLayout;
@property (nonatomic) BOOL didStartInitialRender;
@property (nonatomic) BOOL renderScaleLocked;
@property (nonatomic) double lockedDisplayXHalfRangeMm;
@property (nonatomic) double lockedDisplayYHalfRangeMm;
@end

@implementation DSMainViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _parameters = [DSExperimentParameters defaultParameters];
        _renderQueue = dispatch_queue_create("com.example.DoubleSlitLab.render", DISPATCH_QUEUE_SERIAL);
        _controlsViewController = [[DSControlsViewController alloc] init];
        _controlsViewController.parameters = _parameters;
        _stageViewController = [[DSStageViewController alloc] init];
        _resultsViewController = [[DSResultsViewController alloc] init];

        NSSplitViewItem *controlsItem = [NSSplitViewItem sidebarWithViewController:_controlsViewController];
        controlsItem.minimumThickness = 286.0;
        controlsItem.maximumThickness = 350.0;
        controlsItem.canCollapse = NO;
        controlsItem.holdingPriority = 261.0;

        NSSplitViewItem *stageItem = [NSSplitViewItem splitViewItemWithViewController:_stageViewController];
        stageItem.minimumThickness = 440.0;
        stageItem.canCollapse = NO;
        stageItem.holdingPriority = 250.0;

        NSSplitViewItem *resultsItem = [NSSplitViewItem splitViewItemWithViewController:_resultsViewController];
        resultsItem.minimumThickness = 340.0;
        resultsItem.maximumThickness = 470.0;
        resultsItem.canCollapse = NO;
        resultsItem.holdingPriority = 261.0;

        [self addSplitViewItem:controlsItem];
        [self addSplitViewItem:stageItem];
        [self addSplitViewItem:resultsItem];

        __weak typeof(self) weakSelf = self;
        _controlsViewController.onParametersChanged = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self parametersChanged];
        };
        _controlsViewController.onExportConfiguration = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self exportLabConfiguration:nil];
        };
        _controlsViewController.onLoadConfiguration = ^{
            __strong typeof(weakSelf) self = weakSelf;
            [self loadLabConfiguration:nil];
        };
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.splitView.dividerStyle = NSSplitViewDividerStyleThin;
    self.splitView.vertical = YES;
    self.splitView.wantsLayer = YES;
    self.splitView.layer.backgroundColor = [DSTheme background].CGColor;
    
    // Initialize render scale lock state from results view controller
    self.renderScaleLocked = self.resultsViewController.isDetectorScaleLocked;
    
    [self applyCurrentState];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    if (!self.didConfigureInitialLayout) {
        self.didConfigureInitialLayout = YES;
        CGFloat totalWidth = NSWidth(self.splitView.bounds);
        [self.splitView setPosition:304.0 ofDividerAtIndex:0];
        CGFloat rightEdge = MAX(760.0, totalWidth - 374.0);
        [self.splitView setPosition:rightEdge ofDividerAtIndex:1];
    }
    if (!self.didStartInitialRender) {
        self.didStartInitialRender = YES;
        [self scheduleRender];
    }
}

#pragma mark - State

- (void)parametersChanged {
    [self.parameters clampToValidRange];
    [self applyCurrentState];
    [self scheduleRender];
}

- (void)applyCurrentState {
    [self.stageViewController applyParameters:self.parameters];
    [self.stageViewController setShutterOpen:self.parameters.shutterOpen];
    [self.resultsViewController updateWithParameters:self.parameters result:self.currentPattern];
    [self.resultsViewController setShutterClosed:!self.parameters.shutterOpen];
    [self.controlsViewController syncWithParameters];
}

#pragma mark - Rendering

- (void)scheduleRender {
    self.renderGeneration++;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(beginRender) object:nil];
    [self performSelector:@selector(beginRender) withObject:nil afterDelay:0.045];
}

- (DSPhysicsParameters)physicsParameters {
    DSPhysicsParameters p = DSPhysicsParametersMake(self.parameters.wavelengthNm,
                                                    self.parameters.spectralWidthNm,
                                                    self.parameters.coherenceMode == DSCoherenceModeCoherent,
                                                    [self.parameters isWhiteLight],
                                                    self.parameters.slitCount,
                                                    self.parameters.slitWidthUm * 1e-6,
                                                    self.parameters.slitLengthMm * 1e-3,
                                                    self.parameters.slitPitchUm * 1e-6,
                                                    self.parameters.screenDistanceM);
    return p;
}

- (void)beginRender {
    if (!self.isViewLoaded) {
        return;
    }
    if (self.renderInFlight) {
        self.renderPending = YES;
        return;
    }
    self.renderInFlight = YES;
    uint64_t generation = self.renderGeneration;
    DSPhysicsParameters physics = [self physicsParameters];
    
    double xHalfRangeMm = 0.0;
    double yHalfRangeMm = 0.0;
    if (self.renderScaleLocked && self.lockedDisplayXHalfRangeMm > 0.0) {
        xHalfRangeMm = self.lockedDisplayXHalfRangeMm;
        yHalfRangeMm = self.lockedDisplayYHalfRangeMm;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.renderQueue, ^{
        @autoreleasepool {
            DSPatternResult *result;
            if (xHalfRangeMm > 0.0) {
                result = DSRenderPatternInDisplayRange(&physics, 1000, 600, xHalfRangeMm, yHalfRangeMm);
            } else {
                result = DSRenderPattern(&physics, 1000, 600);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) {
                    return;
                }
                self.renderInFlight = NO;
                if (generation == self.renderGeneration) {
                    self.currentPattern = result;
                    // Initialize locked display range on first render if scale is locked
                    if (self.renderScaleLocked && self.lockedDisplayXHalfRangeMm <= 0.0) {
                        self.lockedDisplayXHalfRangeMm = result.metrics.xHalfRangeMm;
                        self.lockedDisplayYHalfRangeMm = result.metrics.yHalfRangeMm;
                        [self.resultsViewController setLockedDisplayRangeXHalfMm:self.lockedDisplayXHalfRangeMm yHalfMm:self.lockedDisplayYHalfRangeMm];
                    }
                    [self.resultsViewController updateWithParameters:self.parameters result:result];
                    [self.resultsViewController setShutterClosed:!self.parameters.shutterOpen];
                    [self.stageViewController setPatternImage:result.image];
                }
                if (self.renderPending || generation != self.renderGeneration) {
                    self.renderPending = NO;
                    [self beginRender];
                }
            });
        }
    });
}

#pragma mark - Actions

- (IBAction)savePattern:(id)sender {
    [self.resultsViewController savePattern:sender];
}

- (IBAction)exportLabConfiguration:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"Export Lab Configuration";
    panel.nameFieldStringValue = @"double-slit-lab.json";
    panel.allowedContentTypes = @[UTTypeJSON];
    panel.canCreateDirectories = YES;
    panel.extensionHidden = NO;

    NSWindow *window = self.view.window;
    void (^completion)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) {
            return;
        }
        NSError *error = nil;
        NSData *data = [DSLabConfiguration JSONDataForParameters:self.parameters error:&error];
        if (!data) {
            [self presentConfigurationError:@"Could not export the lab configuration" error:error];
            return;
        }
        if (![data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]) {
            [self presentConfigurationError:@"Could not write the lab configuration" error:error];
        }
    };
    if (window) {
        [panel beginSheetModalForWindow:window completionHandler:completion];
    } else {
        completion([panel runModal]);
    }
}

- (IBAction)loadLabConfiguration:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"Load Lab Configuration";
    panel.allowedContentTypes = @[UTTypeJSON];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    panel.resolvesAliases = YES;

    NSWindow *window = self.view.window;
    void (^completion)(NSModalResponse) = ^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) {
            return;
        }
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfURL:panel.URL
                                             options:NSDataReadingMappedIfSafe
                                               error:&error];
        DSExperimentParameters *loaded = data ? [DSLabConfiguration parametersFromJSONData:data error:&error] : nil;
        if (!loaded) {
            [self presentConfigurationError:@"Could not load the lab configuration" error:error];
            return;
        }
        [self.parameters copySettingsFromParameters:loaded];
        [self applyCurrentState];
        [self scheduleRender];
    };
    if (window) {
        [panel beginSheetModalForWindow:window completionHandler:completion];
    } else {
        completion([panel runModal]);
    }
}

- (void)presentConfigurationError:(NSString *)message error:(NSError *)error {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    alert.informativeText = error.localizedDescription ?: @"Unknown error.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"OK"];
    NSWindow *window = self.view.window;
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

- (IBAction)resetExperiment:(id)sender {
    [self.controlsViewController resetExperiment];
}

- (IBAction)resetCamera:(id)sender {
    [self.stageViewController resetCamera];
}

- (IBAction)toggleLabels:(id)sender {
    [self.stageViewController toggleLabels];
}

- (IBAction)showPhysicsInfo:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Physics model";
    alert.informativeText = @"The detector uses the Fraunhofer (far-field) scalar diffraction approximation.\n\n"
                             "For each wavelength, the horizontal intensity is the product of the single-slit envelope "
                             "sinc²(πa sinθ/λ) and, in coherent mode, the N-slit interference factor "
                             "[sin(Nπd sinθ/λ) / (N sin(πd sinθ/λ))]². The vertical direction includes the slit-length "
                             "envelope sinc²(πL sinφ/λ).\n\n"
                             "Coherent mode adds amplitudes across the slits; incoherent mode adds slit intensities, so "
                             "interference fringes vanish. A finite spectral width is integrated wavelength by wavelength, "
                             "producing dispersion and reduced fringe visibility. White light uses a 6500 K broadband "
                             "spectrum.\n\n"
                             "The fringe spacing is Δx ≈ λD/d and the central diffraction-lobe width is 2λD/a. "
                             "The source-to-slit distance changes the physical layout and illumination geometry, but not "
                             "the far-field fringe spacing. Polarisation, near-field (Fresnel) effects and detector noise "
                             "are not modelled.";
    [alert addButtonWithTitle:@"Close"];
    NSWindow *window = self.view.window;
    if (window) {
        [alert beginSheetModalForWindow:window completionHandler:nil];
    } else {
        [alert runModal];
    }
}

@end
