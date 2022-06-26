#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    double wavelengthNm;
    double spectralWidthNm;
    BOOL coherent;
    BOOL whiteLight;
    NSUInteger slitCount;
    double slitWidthM;
    double slitLengthM;
    double slitPitchM;
    double screenDistanceM;
} DSPhysicsParameters;

typedef struct {
    double fringeSpacingMm;
    double centralLobeWidthMm;
    double verticalLobeHeightMm;
    double coherenceLengthMm;
    double visibility;
    double xHalfRangeMm;
    double yHalfRangeMm;
} DSPatternMetrics;

FOUNDATION_EXPORT DSPhysicsParameters DSPhysicsParametersMake(double wavelengthNm,
                                                               double spectralWidthNm,
                                                               BOOL coherent,
                                                               BOOL whiteLight,
                                                               NSUInteger slitCount,
                                                               double slitWidthM,
                                                               double slitLengthM,
                                                               double slitPitchM,
                                                               double screenDistanceM);

FOUNDATION_EXPORT double DSIntensityForWavelength(const DSPhysicsParameters *parameters,
                                                  double wavelengthNm,
                                                  double xMeters,
                                                  double yMeters);

FOUNDATION_EXPORT double DSSingleSlitFactor(double sinTheta, double wavelengthNm, double slitWidthM);
FOUNDATION_EXPORT double DSInterferenceFactor(double sinTheta,
                                              double wavelengthNm,
                                              NSUInteger slitCount,
                                              double slitPitchM);

FOUNDATION_EXPORT DSPatternMetrics DSComputeMetrics(const DSPhysicsParameters *parameters);

@interface DSPatternResult : NSObject
@property (nonatomic) size_t pixelWidth;
@property (nonatomic) size_t pixelHeight;
@property (nonatomic, strong, nullable) NSImage *image;
@property (nonatomic, strong, nullable) NSData *profile;
@property (nonatomic) size_t profileLength;
@property (nonatomic) DSPatternMetrics metrics;
@end

/// Renders an RGB detector image plus a normalised horizontal cross-section.
FOUNDATION_EXPORT DSPatternResult * _Nullable DSRenderPattern(const DSPhysicsParameters *parameters,
                                                              size_t width,
                                                              size_t height);

/// Renders using a fixed physical detector extent. Pass 0 for an axis to
/// auto-fit that axis. A fixed extent makes the change in fringe spacing with
/// screen distance visible, instead of normalising it away.
FOUNDATION_EXPORT DSPatternResult * _Nullable DSRenderPatternInDisplayRange(const DSPhysicsParameters *parameters,
                                                                            size_t width,
                                                                            size_t height,
                                                                            double xHalfRangeMm,
                                                                            double yHalfRangeMm);

NS_ASSUME_NONNULL_END
