#import "DSLabConfiguration.h"
#import "DSExperimentParameters.h"
#import <math.h>

NSString * const DSLabConfigurationErrorDomain = @"com.example.DoubleSlitLab.configuration";

static NSString * const DSLabConfigurationFormat = @"DoubleSlitLabConfiguration";
static const NSInteger DSLabConfigurationVersion = 1;

static NSError *DSConfigurationError(DSLabConfigurationErrorCode code, NSString *description) {
    return [NSError errorWithDomain:DSLabConfigurationErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

/// Rounds away binary floating-point noise so exported JSON stays readable.
static NSNumber *DSNumber(double value) {
    if (!isfinite(value)) {
        return @0;
    }
    return @(round(value * 1e12) / 1e12);
}

static NSString *DSPresetIdentifier(DSLaserPreset preset) {
    switch (preset) {
        case DSLaserPresetHeliumNeon:  return @"heliumNeon";
        case DSLaserPresetArgonIon:    return @"argonIon";
        case DSLaserPresetDPSS:        return @"dpss";
        case DSLaserPresetVioletDiode: return @"violetDiode";
        case DSLaserPresetRedDiode:    return @"redDiode";
        case DSLaserPresetWhiteLight:  return @"whiteLight";
        case DSLaserPresetCustom:      return @"custom";
    }
    return @"custom";
}

static BOOL DSPresetFromIdentifier(NSString *identifier, DSLaserPreset *preset) {
    NSDictionary<NSString *, NSNumber *> *identifiers = @{
        @"heliumNeon":  @(DSLaserPresetHeliumNeon),
        @"argonIon":    @(DSLaserPresetArgonIon),
        @"dpss":        @(DSLaserPresetDPSS),
        @"violetDiode": @(DSLaserPresetVioletDiode),
        @"redDiode":    @(DSLaserPresetRedDiode),
        @"whiteLight":  @(DSLaserPresetWhiteLight),
        @"custom":      @(DSLaserPresetCustom),
    };
    NSNumber *value = identifiers[identifier];
    if (!value) {
        return NO;
    }
    *preset = (DSLaserPreset)value.integerValue;
    return YES;
}

static NSString *DSCoherenceIdentifier(DSCoherenceMode mode) {
    return mode == DSCoherenceModeCoherent ? @"coherent" : @"incoherent";
}

static BOOL DSCoherenceFromIdentifier(NSString *identifier, DSCoherenceMode *mode) {
    if ([identifier isEqualToString:@"coherent"]) {
        *mode = DSCoherenceModeCoherent;
        return YES;
    }
    if ([identifier isEqualToString:@"incoherent"]) {
        *mode = DSCoherenceModeIncoherent;
        return YES;
    }
    return NO;
}

static NSDictionary * _Nullable DSReadDictionary(NSDictionary *container,
                                                 NSString *key,
                                                 NSError **error) {
    id value = container[key];
    if (!value) {
        return @{};
    }
    if (![value isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          [NSString stringWithFormat:@"“%@” must be a JSON object.", key]);
        }
        return nil;
    }
    return value;
}

static BOOL DSReadDouble(NSDictionary *container,
                         NSString *key,
                         double *target,
                         NSError **error) {
    id value = container[key];
    if (!value) {
        return YES;
    }
    if (![value isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          [NSString stringWithFormat:@"“%@” must be a number.", key]);
        }
        return NO;
    }
    double number = [value doubleValue];
    if (!isfinite(number)) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          [NSString stringWithFormat:@"“%@” must be a finite number.", key]);
        }
        return NO;
    }
    *target = number;
    return YES;
}

static BOOL DSReadUnsignedInteger(NSDictionary *container,
                                  NSString *key,
                                  NSUInteger *target,
                                  NSError **error) {
    id value = container[key];
    if (!value) {
        return YES;
    }
    if (![value isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          [NSString stringWithFormat:@"“%@” must be a whole number.", key]);
        }
        return NO;
    }
    double number = [value doubleValue];
    if (!isfinite(number) || number != floor(number) || number < 0.0) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          [NSString stringWithFormat:@"“%@” must be a non-negative whole number.", key]);
        }
        return NO;
    }
    // Clamp before converting so hand-edited extreme values stay well-defined.
    *target = (NSUInteger)fmin(number, 1000000.0);
    return YES;
}

static BOOL DSReadColor(NSDictionary *source, NSColor **color, NSError **error) {
    id value = source[@"beamColor"];
    if (!value) {
        *color = nil;
        return YES;
    }
    if (![value isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          @"“beamColor” must be a JSON object with red, green, blue, and alpha components.");
        }
        return NO;
    }

    double red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
    if (!DSReadDouble(value, @"red", &red, error) ||
        !DSReadDouble(value, @"green", &green, error) ||
        !DSReadDouble(value, @"blue", &blue, error) ||
        !DSReadDouble(value, @"alpha", &alpha, error)) {
        return NO;
    }
    if (!value[@"red"] || !value[@"green"] || !value[@"blue"]) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          @"“beamColor” must include red, green, and blue components.");
        }
        return NO;
    }
    if (red < 0.0 || red > 1.0 ||
        green < 0.0 || green > 1.0 ||
        blue < 0.0 || blue > 1.0 ||
        alpha < 0.0 || alpha > 1.0) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          @"Colour components must be between 0 and 1.");
        }
        return NO;
    }

    *color = [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
    return YES;
}

@implementation DSLabConfiguration

+ (NSString *)formatIdentifier {
    return DSLabConfigurationFormat;
}

+ (NSInteger)currentVersion {
    return DSLabConfigurationVersion;
}

+ (NSData *)JSONDataForParameters:(DSExperimentParameters *)parameters error:(NSError **)error {
    if (!parameters) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                          @"There are no experiment parameters to export.");
        }
        return nil;
    }

    NSColor *color = [parameters.beamColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] ?: [NSColor whiteColor];
    NSDictionary *configuration = @{
        @"format": DSLabConfigurationFormat,
        @"version": @(DSLabConfigurationVersion),
        @"source": @{
            @"preset": DSPresetIdentifier(parameters.laserPreset),
            @"coherence": DSCoherenceIdentifier(parameters.coherenceMode),
            @"wavelengthNm": DSNumber(parameters.wavelengthNm),
            @"spectralWidthNm": DSNumber(parameters.spectralWidthNm),
            @"beamColor": @{
                @"red": DSNumber(color.redComponent),
                @"green": DSNumber(color.greenComponent),
                @"blue": DSNumber(color.blueComponent),
                @"alpha": DSNumber(color.alphaComponent),
            },
        },
        @"aperture": @{
            @"slitCount": @(parameters.slitCount),
            @"slitWidthUm": DSNumber(parameters.slitWidthUm),
            @"slitLengthMm": DSNumber(parameters.slitLengthMm),
            @"slitPitchUm": DSNumber(parameters.slitPitchUm),
        },
        @"bench": @{
            @"laserDistanceM": DSNumber(parameters.laserDistanceM),
            @"screenDistanceM": DSNumber(parameters.screenDistanceM),
            @"shutterOpen": @(parameters.shutterOpen),
        },
    };

    return [NSJSONSerialization dataWithJSONObject:configuration
                                           options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                             error:error];
}

+ (DSExperimentParameters *)parametersFromJSONData:(NSData *)data error:(NSError **)error {
    if (data.length == 0) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidFormat,
                                          @"The configuration file is empty.");
        }
        return nil;
    }

    NSError *jsonError = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (![root isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *message = jsonError.localizedDescription;
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidFormat,
                                          message.length > 0
                                              ? [NSString stringWithFormat:@"The file is not valid JSON: %@", message]
                                              : @"The file is not a valid JSON configuration.");
        }
        return nil;
    }

    NSDictionary *configuration = root;
    id format = configuration[@"format"];
    if (![format isKindOfClass:[NSString class]] ||
        ![format isEqualToString:DSLabConfigurationFormat]) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidFormat,
                                          @"This file is not a Double-Slit Lab configuration.");
        }
        return nil;
    }

    id versionValue = configuration[@"version"];
    if (![versionValue isKindOfClass:[NSNumber class]]) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorInvalidFormat,
                                          @"The configuration is missing its format version.");
        }
        return nil;
    }
    double versionNumber = [versionValue doubleValue];
    if (!isfinite(versionNumber) || versionNumber != floor(versionNumber) ||
        versionNumber < 1.0 || versionNumber > (double)DSLabConfigurationVersion) {
        if (error) {
            *error = DSConfigurationError(DSLabConfigurationErrorUnsupportedVersion,
                                          [NSString stringWithFormat:@"This configuration uses unsupported version %@. "
                                           "Double-Slit Lab supports version %ld.",
                                           versionValue, (long)DSLabConfigurationVersion]);
        }
        return nil;
    }

    NSDictionary *source = DSReadDictionary(configuration, @"source", error);
    NSDictionary *aperture = DSReadDictionary(configuration, @"aperture", error);
    NSDictionary *bench = DSReadDictionary(configuration, @"bench", error);
    if (!source || !aperture || !bench) {
        return nil;
    }

    DSExperimentParameters *parameters = [DSExperimentParameters defaultParameters];

    id presetValue = source[@"preset"];
    if (presetValue) {
        if (![presetValue isKindOfClass:[NSString class]]) {
            if (error) {
                *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                              @"“preset” must be a string.");
            }
            return nil;
        }
        DSLaserPreset preset = DSLaserPresetCustom;
        if (!DSPresetFromIdentifier(presetValue, &preset)) {
            if (error) {
                *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                              [NSString stringWithFormat:@"Unknown laser preset “%@”.", presetValue]);
            }
            return nil;
        }
        [parameters applyLaserPreset:preset];
    }

    id coherenceValue = source[@"coherence"];
    if (coherenceValue) {
        if (![coherenceValue isKindOfClass:[NSString class]]) {
            if (error) {
                *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                              @"“coherence” must be a string.");
            }
            return nil;
        }
        DSCoherenceMode mode = DSCoherenceModeCoherent;
        if (!DSCoherenceFromIdentifier(coherenceValue, &mode)) {
            if (error) {
                *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                              [NSString stringWithFormat:@"Unknown coherence mode “%@”.", coherenceValue]);
            }
            return nil;
        }
        parameters.coherenceMode = mode;
    }

    double wavelengthNm = parameters.wavelengthNm;
    double spectralWidthNm = parameters.spectralWidthNm;
    double laserDistanceM = parameters.laserDistanceM;
    double slitWidthUm = parameters.slitWidthUm;
    double slitLengthMm = parameters.slitLengthMm;
    double slitPitchUm = parameters.slitPitchUm;
    double screenDistanceM = parameters.screenDistanceM;
    NSUInteger slitCount = parameters.slitCount;

    if (!DSReadDouble(source, @"wavelengthNm", &wavelengthNm, error) ||
        !DSReadDouble(source, @"spectralWidthNm", &spectralWidthNm, error) ||
        !DSReadDouble(aperture, @"slitWidthUm", &slitWidthUm, error) ||
        !DSReadDouble(aperture, @"slitLengthMm", &slitLengthMm, error) ||
        !DSReadDouble(aperture, @"slitPitchUm", &slitPitchUm, error) ||
        !DSReadDouble(bench, @"laserDistanceM", &laserDistanceM, error) ||
        !DSReadDouble(bench, @"screenDistanceM", &screenDistanceM, error) ||
        !DSReadUnsignedInteger(aperture, @"slitCount", &slitCount, error)) {
        return nil;
    }

    parameters.wavelengthNm = wavelengthNm;
    parameters.spectralWidthNm = spectralWidthNm;
    parameters.laserDistanceM = laserDistanceM;
    parameters.slitWidthUm = slitWidthUm;
    parameters.slitLengthMm = slitLengthMm;
    parameters.slitPitchUm = slitPitchUm;
    parameters.screenDistanceM = screenDistanceM;
    parameters.slitCount = slitCount;

    NSColor *beamColor = nil;
    if (!DSReadColor(source, &beamColor, error)) {
        return nil;
    }
    // A missing colour is derived from the preset and wavelength in
    // clampToValidRange, so partial files still produce a consistent bench.
    parameters.beamColor = beamColor;

    id shutterValue = bench[@"shutterOpen"];
    if (shutterValue) {
        if (![shutterValue isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = DSConfigurationError(DSLabConfigurationErrorInvalidValue,
                                              @"“shutterOpen” must be true or false.");
            }
            return nil;
        }
        parameters.shutterOpen = [shutterValue boolValue];
    }

    [parameters clampToValidRange];
    return parameters;
}

@end
