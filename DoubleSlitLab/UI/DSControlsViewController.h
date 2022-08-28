#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DSExperimentParameters;

@interface DSControlsViewController : NSViewController

@property (nonatomic, strong) DSExperimentParameters *parameters;
@property (nonatomic, copy, nullable) void (^onParametersChanged)(void);
@property (nonatomic, copy, nullable) void (^onExportConfiguration)(void);
@property (nonatomic, copy, nullable) void (^onLoadConfiguration)(void);
- (void)syncWithParameters;
- (void)resetExperiment;

@end

NS_ASSUME_NONNULL_END
