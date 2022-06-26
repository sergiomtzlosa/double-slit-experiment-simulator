#import "DSExperimentParameters.h"
#import "DSColorScience.h"
#import <math.h>

static double DSClampDouble(double value, double low, double high) {
    return value < low ? low : (value > high ? high : value);
}

@implementation DSExperimentParameters

+ (instancetype)defaultParameters {
    DSExperimentParameters *parameters = [[DSExperimentParameters alloc] init];
    parameters.laserDistanceM = 0.35;
    parameters.slitCount = 2;
    parameters.slitWidthUm = 40.0;
    parameters.slitLengthMm = 4.0;
    parameters.slitPitchUm = 250.0;
    parameters.screenDistanceM = 1.5;
    parameters.shutterOpen = YES;
    [parameters applyLaserPreset:DSLaserPresetHeliumNeon];
    [parameters clampToValidRange];
    return parameters;
}

- (void)applyLaserPreset:(DSLaserPreset)preset {
    BOOL wasWhite = [self isWhiteLight];
    self.laserPreset = preset;
    switch (preset) {
        case DSLaserPresetHeliumNeon:
            self.wavelengthNm = 632.8;
            self.spectralWidthNm = 0.002;
            self.coherenceMode = DSCoherenceModeCoherent;
            self.beamColor = DSColorForWavelength(self.wavelengthNm);
            break;
        case DSLaserPresetArgonIon:
            self.wavelengthNm = 488.0;
            self.spectralWidthNm = 0.02;
            self.coherenceMode = DSCoherenceModeCoherent;
            self.beamColor = DSColorForWavelength(self.wavelengthNm);
            break;
        case DSLaserPresetDPSS:
            self.wavelengthNm = 532.0;
            self.spectralWidthNm = 0.1;
            self.coherenceMode = DSCoherenceModeCoherent;
            self.beamColor = DSColorForWavelength(self.wavelengthNm);
            break;
        case DSLaserPresetVioletDiode:
            self.wavelengthNm = 405.0;
            self.spectralWidthNm = 0.5;
            self.coherenceMode = DSCoherenceModeCoherent;
            self.beamColor = DSColorForWavelength(self.wavelengthNm);
            break;
        case DSLaserPresetRedDiode:
            self.wavelengthNm = 650.0;
            self.spectralWidthNm = 1.0;
            self.coherenceMode = DSCoherenceModeCoherent;
            self.beamColor = DSColorForWavelength(self.wavelengthNm);
            break;
        case DSLaserPresetWhiteLight:
            self.wavelengthNm = 550.0;
            self.spectralWidthNm = 300.0;
            self.coherenceMode = DSCoherenceModeIncoherent;
            self.beamColor = DSColorForWhiteLight();
            break;
        case DSLaserPresetCustom:
            if (wasWhite) {
                self.wavelengthNm = 550.0;
                self.spectralWidthNm = 0.05;
                self.coherenceMode = DSCoherenceModeCoherent;
            }
            self.beamColor = DSColorForWavelength(self.wavelengthNm);
            break;
    }
    [self clampToValidRange];
}

- (void)applyCustomWavelength:(double)wavelengthNm {
    BOOL wasWhite = [self isWhiteLight];
    self.laserPreset = DSLaserPresetCustom;
    self.wavelengthNm = wavelengthNm;
    if (wasWhite || self.spectralWidthNm > 5.0) {
        self.spectralWidthNm = 0.05;
    }
    if (wasWhite) {
        self.coherenceMode = DSCoherenceModeCoherent;
    }
    self.beamColor = DSColorForWavelength(self.wavelengthNm);
    [self clampToValidRange];
}

- (void)applyBeamColor:(NSColor *)color {
    NSColor *srgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (!srgb) {
        srgb = DSColorForWavelength(self.wavelengthNm);
    }
    CGFloat hue = 0.0, saturation = 0.0, brightness = 0.0, alpha = 1.0;
    [srgb getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

    if (saturation < 0.12 || brightness < 0.04) {
        [self applyLaserPreset:DSLaserPresetWhiteLight];
        return;
    }

    BOOL wasWhite = [self isWhiteLight];
    BOOL wasBroadband = self.spectralWidthNm > 5.0;
    self.laserPreset = DSLaserPresetCustom;
    self.wavelengthNm = DSWavelengthForHue(hue);
    if (wasWhite || wasBroadband) {
        self.spectralWidthNm = 0.05;
    }
    if (wasWhite) {
        self.coherenceMode = DSCoherenceModeCoherent;
    }
    // A laser colour is a wavelength. Snapping the swatch to the corresponding
    // spectral colour keeps the bench, aperture, and detected pattern in sync.
    self.beamColor = DSColorForWavelength(self.wavelengthNm);
    [self clampToValidRange];
}

- (void)clampToValidRange {
    if (self.laserPreset < DSLaserPresetHeliumNeon || self.laserPreset > DSLaserPresetCustom) {
        self.laserPreset = DSLaserPresetCustom;
    }
    self.wavelengthNm = DSClampDouble(self.wavelengthNm, 380.0, 780.0);
    self.spectralWidthNm = DSClampDouble(self.spectralWidthNm, 0.001, 300.0);
    self.laserDistanceM = DSClampDouble(self.laserDistanceM, 0.10, 2.00);
    if (self.slitCount < 1) self.slitCount = 1;
    if (self.slitCount > 8) self.slitCount = 8;
    self.slitWidthUm = DSClampDouble(self.slitWidthUm, 2.0, 200.0);
    self.slitLengthMm = DSClampDouble(self.slitLengthMm, 0.10, 20.0);
    self.screenDistanceM = DSClampDouble(self.screenDistanceM, 0.20, 5.00);

    double minimumPitch = self.slitWidthUm + 2.0;
    self.slitPitchUm = DSClampDouble(self.slitPitchUm,
                                     fmax(20.0, minimumPitch),
                                     2000.0);

    if (!self.beamColor) {
        self.beamColor = [self isWhiteLight] ? DSColorForWhiteLight()
                                             : DSColorForWavelength(self.wavelengthNm);
    }
}

- (BOOL)isWhiteLight {
    return self.laserPreset == DSLaserPresetWhiteLight;
}

- (NSString *)laserPresetDisplayName {
    switch (self.laserPreset) {
        case DSLaserPresetHeliumNeon: return @"Helium–Neon (633 nm)";
        case DSLaserPresetArgonIon:   return @"Argon-ion (488 nm)";
        case DSLaserPresetDPSS:       return @"DPSS green (532 nm)";
        case DSLaserPresetVioletDiode:return @"Violet diode (405 nm)";
        case DSLaserPresetRedDiode:   return @"Red diode (650 nm)";
        case DSLaserPresetWhiteLight: return @"White light (6500 K)";
        case DSLaserPresetCustom:     return @"Custom colour";
    }
    return @"Custom colour";
}

- (NSString *)laserPresetShortName {
    switch (self.laserPreset) {
        case DSLaserPresetHeliumNeon: return @"He–Ne";
        case DSLaserPresetArgonIon:   return @"Ar⁺";
        case DSLaserPresetDPSS:       return @"DPSS";
        case DSLaserPresetVioletDiode:return @"Violet diode";
        case DSLaserPresetRedDiode:   return @"Red diode";
        case DSLaserPresetWhiteLight: return @"White light";
        case DSLaserPresetCustom:     return @"Custom";
    }
    return @"Custom";
}

@end
