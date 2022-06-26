#import <Cocoa/Cocoa.h>
#import "DSAppDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        DSAppDelegate *delegate = [[DSAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
