#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DSExperimentParameters;

@interface DSStageViewController : NSViewController

@property (nonatomic, readonly) BOOL labelsVisible;

- (void)applyParameters:(DSExperimentParameters *)parameters;
- (void)setPatternImage:(nullable NSImage *)image;
- (void)setShutterOpen:(BOOL)open;
- (void)resetCamera;
- (void)toggleLabels;

@end

NS_ASSUME_NONNULL_END
