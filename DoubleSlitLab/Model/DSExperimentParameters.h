#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSCoherenceMode) {
    DSCoherenceModeCoherent = 0,
    DSCoherenceModeIncoherent = 1
};

typedef NS_ENUM(NSInteger, DSLaserPreset) {
    DSLaserPresetHeliumNeon = 0,
    DSLaserPresetArgonIon = 1,
    DSLaserPresetDPSS = 2,
    DSLaserPresetVioletDiode = 3,
    DSLaserPresetRedDiode = 4,
    DSLaserPresetWhiteLight = 5,
    DSLaserPresetCustom = 6
};

@interface DSExperimentParameters : NSObject

@property (nonatomic) DSLaserPreset laserPreset;
@property (nonatomic) DSCoherenceMode coherenceMode;
@property (nonatomic) double wavelengthNm;
@property (nonatomic) double spectralWidthNm;
@property (nonatomic) double laserDistanceM;
@property (nonatomic) NSUInteger slitCount;
@property (nonatomic) double slitWidthUm;
@property (nonatomic) double slitLengthMm;
@property (nonatomic) double slitPitchUm;
@property (nonatomic) double screenDistanceM;
@property (nonatomic) BOOL shutterOpen;
@property (nonatomic, strong) NSColor *beamColor;

+ (instancetype)defaultParameters;

- (void)applyLaserPreset:(DSLaserPreset)preset;
- (void)applyCustomWavelength:(double)wavelengthNm;
- (void)applyBeamColor:(NSColor *)color;
- (void)copySettingsFromParameters:(DSExperimentParameters *)parameters;
- (void)clampToValidRange;

- (BOOL)isWhiteLight;
- (NSString *)laserPresetDisplayName;
- (NSString *)laserPresetShortName;

@end

NS_ASSUME_NONNULL_END
