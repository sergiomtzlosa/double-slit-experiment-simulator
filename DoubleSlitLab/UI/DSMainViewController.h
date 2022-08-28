#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMainViewController : NSSplitViewController

- (IBAction)savePattern:(nullable id)sender;
- (IBAction)exportLabConfiguration:(nullable id)sender;
- (IBAction)loadLabConfiguration:(nullable id)sender;
- (IBAction)resetExperiment:(nullable id)sender;
- (IBAction)resetCamera:(nullable id)sender;
- (IBAction)toggleLabels:(nullable id)sender;
- (IBAction)showPhysicsInfo:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
