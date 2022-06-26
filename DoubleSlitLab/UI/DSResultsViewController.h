#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DSExperimentParameters;
@class DSPatternResult;

@interface DSResultsViewController : NSViewController

@property (nonatomic, strong, readonly, nullable) NSImage *currentImage;
@property (nonatomic, readonly, getter=isDetectorScaleLocked) BOOL detectorScaleLocked;

- (void)updateWithParameters:(DSExperimentParameters *)parameters result:(nullable DSPatternResult *)result;
- (void)setShutterClosed:(BOOL)closed;
- (void)savePattern:(nullable id)sender;
- (void)getCurrentDisplayRangeXHalfMm:(double *)xHalfRangeMm yHalfMm:(double *)yHalfRangeMm;
- (void)setLockedDisplayRangeXHalfMm:(double)xHalfRangeMm yHalfMm:(double)yHalfRangeMm;

@end

NS_ASSUME_NONNULL_END
