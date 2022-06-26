#import "DSAppDelegate.h"
#import "DSMainViewController.h"
#import "DSTheme.h"

@interface DSAppDelegate ()
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) DSMainViewController *mainViewController;
@property (nonatomic, strong) NSMenuItem *resetCameraMenuItem;
@end

@implementation DSAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [self buildMainMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSRect frame = NSMakeRect(0.0, 0.0, 1440.0, 900.0);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable;
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Double-Slit Lab";
    self.window.subtitle = @"Fraunhofer diffraction simulator";
    self.window.minSize = NSMakeSize(1120.0, 720.0);
    self.window.backgroundColor = [DSTheme background];
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.window.tabbingMode = NSWindowTabbingModeDisallowed;
    self.window.releasedWhenClosed = NO;
    [self.window setFrameAutosaveName:@"DoubleSlitLabMainWindow"];

    self.mainViewController = [[DSMainViewController alloc] init];
    self.window.contentViewController = self.mainViewController;
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

#pragma mark - Menu

- (void)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];
    NSString *appName = @"Double-Slit Lab";

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];
    appMenuItem.submenu = appMenu;
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"About %@", appName]
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Hide %@", appName]
                       action:@selector(hide:)
                keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others"
                                                action:@selector(hideOtherApplications:)
                                         keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagOption | NSEventModifierFlagCommand;
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Quit %@", appName]
                       action:@selector(terminate:)
                keyEquivalent:@"q"];

    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    [mainMenu addItem:fileMenuItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    fileMenuItem.submenu = fileMenu;
    [fileMenu addItemWithTitle:@"Save Pattern…" action:@selector(savePattern:) keyEquivalent:@"s"];
    [fileMenu addItemWithTitle:@"Reset Experiment" action:@selector(resetExperiment:) keyEquivalent:@""];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    editMenuItem.submenu = editMenu;
    [editMenu addItemWithTitle:@"Undo" action:NSSelectorFromString(@"undo:") keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo" action:NSSelectorFromString(@"redo:") keyEquivalent:@"Z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    [mainMenu addItem:viewMenuItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    viewMenuItem.submenu = viewMenu;
    [viewMenu addItemWithTitle:@"Toggle Labels" action:@selector(toggleLabels:) keyEquivalent:@"l"];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *fullScreen = [viewMenu addItemWithTitle:@"Enter Full Screen"
                                                 action:@selector(toggleFullScreen:)
                                          keyEquivalent:@"f"];
    fullScreen.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagCommand;

    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    [mainMenu addItem:windowMenuItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    windowMenuItem.submenu = windowMenu;
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
    NSApp.windowsMenu = windowMenu;

    NSMenuItem *helpMenuItem = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
    [mainMenu addItem:helpMenuItem];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    helpMenuItem.submenu = helpMenu;
    [helpMenu addItemWithTitle:@"Physics Model…" action:@selector(showPhysicsInfo:) keyEquivalent:@"?"];

    NSApp.mainMenu = mainMenu;
}

@end
