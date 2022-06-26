#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSExperimentParameters;

@interface DSSceneController : NSObject

@property (nonatomic, readonly) BOOL labelsVisible;

- (instancetype)initWithSceneView:(SCNView *)sceneView;
- (void)applyParameters:(DSExperimentParameters *)parameters;
- (void)setPatternImage:(nullable NSImage *)image;
- (void)setShutterOpen:(BOOL)open;
- (void)setLabelsVisible:(BOOL)visible;
- (void)resetCamera;

@end

NS_ASSUME_NONNULL_END
