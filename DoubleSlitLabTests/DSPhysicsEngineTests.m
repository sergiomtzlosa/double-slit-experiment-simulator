#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "DSPhysicsEngine.h"
#import "DSColorScience.h"
#import "DSExperimentParameters.h"
#import "DSLabConfiguration.h"

@interface DSPhysicsEngineTests : XCTestCase
@end

@implementation DSPhysicsEngineTests

- (DSPhysicsParameters)defaultPhysics {
    return DSPhysicsParametersMake(632.8, 0.002, YES, NO, 2,
                                   40e-6, 4e-3, 250e-6, 1.5);
}

- (void)testCentralMaximumIsUnity {
    DSPhysicsParameters p = [self defaultPhysics];
    double value = DSIntensityForWavelength(&p, p.wavelengthNm, 0.0, 0.0);
    XCTAssertEqualWithAccuracy(value, 1.0, 1e-6);
}

- (void)testDoubleSlitFirstMinimum {
    DSPhysicsParameters p = [self defaultPhysics];
    double wavelengthM = p.wavelengthNm * 1e-9;
    double sinTheta = wavelengthM / (2.0 * p.slitPitchM);
    double x = p.screenDistanceM * tan(asin(sinTheta));
    double value = DSIntensityForWavelength(&p, p.wavelengthNm, x, 0.0);
    XCTAssertLessThan(value, 1e-6);
}

- (void)testIncidenceIsSymmetric {
    DSPhysicsParameters p = [self defaultPhysics];
    double a = DSIntensityForWavelength(&p, p.wavelengthNm, 0.00123, 0.00017);
    double b = DSIntensityForWavelength(&p, p.wavelengthNm, -0.00123, 0.00017);
    XCTAssertEqualWithAccuracy(a, b, 1e-9);
}

- (void)testIncoherentModeHasNoInterferenceNulls {
    DSPhysicsParameters coherent = [self defaultPhysics];
    DSPhysicsParameters incoherent = coherent;
    incoherent.coherent = NO;

    double wavelengthM = coherent.wavelengthNm * 1e-9;
    double sinTheta = wavelengthM / (2.0 * coherent.slitPitchM);
    double x = coherent.screenDistanceM * tan(asin(sinTheta));

    double coherentValue = DSIntensityForWavelength(&coherent, coherent.wavelengthNm, x, 0.0);
    double incoherentValue = DSIntensityForWavelength(&incoherent, incoherent.wavelengthNm, x, 0.0);
    XCTAssertLessThan(coherentValue, 1e-6);
    XCTAssertGreaterThan(incoherentValue, 0.5);
}

- (void)testIncoherentSlitCountDoesNotChangeNormalisedPattern {
    DSPhysicsParameters one = [self defaultPhysics];
    one.slitCount = 1;
    one.coherent = NO;
    DSPhysicsParameters four = one;
    four.slitCount = 4;
    double x = 0.0021;
    double y = 0.0002;
    XCTAssertEqualWithAccuracy(DSIntensityForWavelength(&one, one.wavelengthNm, x, y),
                               DSIntensityForWavelength(&four, four.wavelengthNm, x, y),
                               1e-12);
}

- (void)testMoreSlitsProduceNarrowerInterferenceMaxima {
    DSPhysicsParameters two = [self defaultPhysics];
    DSPhysicsParameters four = [self defaultPhysics];
    four.slitCount = 4;

    double wavelengthM = four.wavelengthNm * 1e-9;
    double sinTheta = wavelengthM / (4.0 * four.slitPitchM);
    double x = four.screenDistanceM * tan(asin(sinTheta));

    double twoValue = DSIntensityForWavelength(&two, two.wavelengthNm, x, 0.0);
    double fourValue = DSIntensityForWavelength(&four, four.wavelengthNm, x, 0.0);
    XCTAssertLessThan(fourValue, 1e-6);
    XCTAssertGreaterThan(twoValue, 0.2);
}

- (void)testMetricsMatchAnalyticFringeSpacing {
    DSPhysicsParameters p = [self defaultPhysics];
    DSPatternMetrics metrics = DSComputeMetrics(&p);
    double expectedMm = p.wavelengthNm * 1e-9 * p.screenDistanceM / p.slitPitchM * 1000.0;
    XCTAssertEqualWithAccuracy(metrics.fringeSpacingMm, expectedMm, 1e-9);
    XCTAssertGreaterThan(metrics.centralLobeWidthMm, 0.0);
    XCTAssertGreaterThan(metrics.xHalfRangeMm, 0.0);
    XCTAssertGreaterThan(metrics.yHalfRangeMm, 0.0);
    XCTAssertGreaterThan(metrics.visibility, 0.9);
}

- (void)testBroadLinewidthReducesVisibility {
    DSPhysicsParameters narrow = [self defaultPhysics];
    DSPatternMetrics narrowMetrics = DSComputeMetrics(&narrow);

    DSPhysicsParameters broad = narrow;
    broad.spectralWidthNm = 80.0;
    DSPatternMetrics broadMetrics = DSComputeMetrics(&broad);

    XCTAssertGreaterThan(narrowMetrics.visibility, 0.9);
    XCTAssertLessThan(broadMetrics.visibility, narrowMetrics.visibility);
}

- (void)testRenderProducesImageAndProfile {
    DSPhysicsParameters p = [self defaultPhysics];
    DSPatternResult *result = DSRenderPattern(&p, 240, 144);
    XCTAssertNotNil(result);
    XCTAssertNotNil(result.image);
    XCTAssertEqual(result.pixelWidth, (size_t)240);
    XCTAssertEqual(result.pixelHeight, (size_t)144);
    XCTAssertEqual(result.profileLength, (size_t)240);
    XCTAssertEqual(result.profile.length, 240 * sizeof(float));
    XCTAssertGreaterThan(result.metrics.xHalfRangeMm, 0.0);
}

- (void)testRedLaserDominatesRedChannel {
    DSPhysicsParameters p = DSPhysicsParametersMake(650.0, 0.1, YES, NO, 2,
                                                    40e-6, 4e-3, 250e-6, 1.5);
    DSPatternResult *result = DSRenderPattern(&p, 120, 72);
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[result.image TIFFRepresentation]];
    XCTAssertNotNil(rep);
    NSColor *center = [[rep colorAtX:60 y:36] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertGreaterThan(center.redComponent, center.blueComponent);
    XCTAssertGreaterThan(center.redComponent, center.greenComponent);
}

- (void)testColorSciencePrimaryWavelengths {
    NSColor *red = [DSColorForWavelength(650.0) colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    NSColor *blue = [DSColorForWavelength(450.0) colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertGreaterThan(red.redComponent, red.greenComponent);
    XCTAssertGreaterThan(red.redComponent, red.blueComponent);
    XCTAssertGreaterThan(blue.blueComponent, blue.redComponent);
}

- (void)testWhiteLightColorIsNearlyNeutral {
    NSColor *white = [DSColorForWhiteLight() colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    double maxComponent = fmax(white.redComponent, fmax(white.greenComponent, white.blueComponent));
    double minComponent = fmin(white.redComponent, fmin(white.greenComponent, white.blueComponent));
    XCTAssertLessThan(maxComponent - minComponent, 0.2);
}

- (void)testParameterClamping {
    DSExperimentParameters *parameters = [DSExperimentParameters defaultParameters];
    parameters.slitCount = 99;
    parameters.slitWidthUm = 200.0;
    parameters.slitPitchUm = 20.0;
    parameters.screenDistanceM = 100.0;
    [parameters clampToValidRange];
    XCTAssertEqual(parameters.slitCount, (NSUInteger)8);
    XCTAssertGreaterThan(parameters.slitPitchUm, parameters.slitWidthUm);
    XCTAssertLessThanOrEqual(parameters.screenDistanceM, 5.0);
}

- (void)testSlitLengthEnvelopeReachesMinimum {
    DSPhysicsParameters p = [self defaultPhysics];
    double wavelengthM = p.wavelengthNm * 1e-9;
    double sinPhi = wavelengthM / p.slitLengthM;
    double y = p.screenDistanceM * tan(asin(sinPhi));
    double value = DSIntensityForWavelength(&p, p.wavelengthNm, 0.0, y);
    XCTAssertLessThan(value, 1e-6);
}

- (void)testCustomColourSnapsToSpectralColour {
    DSExperimentParameters *parameters = [DSExperimentParameters defaultParameters];
    [parameters applyBeamColor:[NSColor colorWithSRGBRed:0.15 green:0.45 blue:1.0 alpha:1.0]];
    XCTAssertEqual(parameters.laserPreset, DSLaserPresetCustom);
    XCTAssertGreaterThanOrEqual(parameters.wavelengthNm, 380.0);
    XCTAssertLessThanOrEqual(parameters.wavelengthNm, 780.0);

    NSColor *expected = [DSColorForWavelength(parameters.wavelengthNm) colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    NSColor *actual = [parameters.beamColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertEqualWithAccuracy(actual.redComponent, expected.redComponent, 1e-6);
    XCTAssertEqualWithAccuracy(actual.greenComponent, expected.greenComponent, 1e-6);
    XCTAssertEqualWithAccuracy(actual.blueComponent, expected.blueComponent, 1e-6);
}

- (void)testWhiteLightPresetAndCustomExit {
    DSExperimentParameters *parameters = [DSExperimentParameters defaultParameters];
    [parameters applyLaserPreset:DSLaserPresetWhiteLight];
    XCTAssertTrue([parameters isWhiteLight]);
    XCTAssertEqual(parameters.coherenceMode, DSCoherenceModeIncoherent);
    XCTAssertEqualWithAccuracy(parameters.spectralWidthNm, 300.0, 1e-9);

    [parameters applyLaserPreset:DSLaserPresetCustom];
    XCTAssertFalse([parameters isWhiteLight]);
    XCTAssertEqual(parameters.coherenceMode, DSCoherenceModeCoherent);
    XCTAssertLessThan(parameters.spectralWidthNm, 5.0);
}

- (void)testLongWavelengthsRemainRed {
    NSColor *red = [DSColorForWavelength(700.0) colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertGreaterThan(red.redComponent, 0.95);
    XCTAssertLessThan(red.greenComponent, 0.05);
    XCTAssertLessThan(red.blueComponent, 0.05);
}

- (void)testHueInverseStaysOnSpectralLocus {
    double orangeNm = DSWavelengthForHue(0.083);
    XCTAssertEqualWithAccuracy(orangeNm, 589.0, 2.0);
    NSColor *orange = [DSColorForWavelength(orangeNm) colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertGreaterThan(orange.greenComponent, 0.3);
    XCTAssertLessThan(orange.greenComponent, 0.7);

    // Purple is non-spectral; hue 0.8 must snap to violet, not interpolate
    // across the hue wheel through green.
    double violetNm = DSWavelengthForHue(0.8);
    XCTAssertEqualWithAccuracy(violetNm, 410.0, 1.0);
    NSColor *violet = [DSColorForWavelength(violetNm) colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertGreaterThan(violet.blueComponent, 0.9);
    XCTAssertLessThan(violet.greenComponent, 0.2);
}

- (void)testAllPresetsRenderWithoutFailure {
    NSArray<NSNumber *> *presets = @[
        @(DSLaserPresetHeliumNeon),
        @(DSLaserPresetArgonIon),
        @(DSLaserPresetDPSS),
        @(DSLaserPresetVioletDiode),
        @(DSLaserPresetRedDiode),
        @(DSLaserPresetWhiteLight),
        @(DSLaserPresetCustom)
    ];
    for (NSNumber *preset in presets) {
        DSExperimentParameters *parameters = [DSExperimentParameters defaultParameters];
        [parameters applyLaserPreset:(DSLaserPreset)preset.integerValue];
        DSPhysicsParameters physics = DSPhysicsParametersMake(parameters.wavelengthNm,
                                                               parameters.spectralWidthNm,
                                                               parameters.coherenceMode == DSCoherenceModeCoherent,
                                                               [parameters isWhiteLight],
                                                               parameters.slitCount,
                                                               parameters.slitWidthUm * 1e-6,
                                                               parameters.slitLengthMm * 1e-3,
                                                               parameters.slitPitchUm * 1e-6,
                                                               parameters.screenDistanceM);
        DSPatternResult *result = DSRenderPattern(&physics, 120, 72);
        XCTAssertNotNil(result, @"Preset %@ failed to render", preset);
        XCTAssertNotNil(result.image);
        XCTAssertGreaterThan(result.metrics.xHalfRangeMm, 0.0);
        XCTAssertGreaterThan(result.metrics.yHalfRangeMm, 0.0);
    }
}

#pragma mark - Configuration

- (void)testConfigurationRoundTripPreservesParameters {
    DSExperimentParameters *original = [DSExperimentParameters defaultParameters];
    [original applyLaserPreset:DSLaserPresetDPSS];
    [original applyCustomWavelength:515.5];
    original.spectralWidthNm = 0.08;
    original.coherenceMode = DSCoherenceModeIncoherent;
    original.laserDistanceM = 0.42;
    original.slitCount = 5;
    original.slitWidthUm = 55.0;
    original.slitLengthMm = 3.25;
    original.slitPitchUm = 310.0;
    original.screenDistanceM = 2.4;
    original.shutterOpen = NO;
    [original clampToValidRange];

    NSError *error = nil;
    NSData *data = [DSLabConfiguration JSONDataForParameters:original error:&error];
    XCTAssertNotNil(data, @"Export failed: %@", error);
    DSExperimentParameters *loaded = [DSLabConfiguration parametersFromJSONData:data error:&error];
    XCTAssertNotNil(loaded, @"Load failed: %@", error);

    XCTAssertEqual(loaded.laserPreset, original.laserPreset);
    XCTAssertEqual(loaded.coherenceMode, original.coherenceMode);
    XCTAssertEqual(loaded.slitCount, original.slitCount);
    XCTAssertEqual(loaded.shutterOpen, original.shutterOpen);
    XCTAssertEqualWithAccuracy(loaded.wavelengthNm, original.wavelengthNm, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.spectralWidthNm, original.spectralWidthNm, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.laserDistanceM, original.laserDistanceM, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.slitWidthUm, original.slitWidthUm, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.slitLengthMm, original.slitLengthMm, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.slitPitchUm, original.slitPitchUm, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.screenDistanceM, original.screenDistanceM, 1e-9);

    NSColor *expectedColor = [original.beamColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    NSColor *loadedColor = [loaded.beamColor colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertNotNil(expectedColor);
    XCTAssertNotNil(loadedColor);
    XCTAssertEqualWithAccuracy(loadedColor.redComponent, expectedColor.redComponent, 1e-9);
    XCTAssertEqualWithAccuracy(loadedColor.greenComponent, expectedColor.greenComponent, 1e-9);
    XCTAssertEqualWithAccuracy(loadedColor.blueComponent, expectedColor.blueComponent, 1e-9);
}

- (void)testConfigurationRoundTripWhiteLight {
    DSExperimentParameters *original = [DSExperimentParameters defaultParameters];
    [original applyLaserPreset:DSLaserPresetWhiteLight];
    original.coherenceMode = DSCoherenceModeCoherent;
    original.screenDistanceM = 3.1;
    [original clampToValidRange];

    NSError *error = nil;
    NSData *data = [DSLabConfiguration JSONDataForParameters:original error:&error];
    XCTAssertNotNil(data, @"Export failed: %@", error);
    DSExperimentParameters *loaded = [DSLabConfiguration parametersFromJSONData:data error:&error];
    XCTAssertNotNil(loaded, @"Load failed: %@", error);

    XCTAssertTrue([loaded isWhiteLight]);
    XCTAssertEqual(loaded.coherenceMode, DSCoherenceModeCoherent);
    XCTAssertEqualWithAccuracy(loaded.spectralWidthNm, 300.0, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.screenDistanceM, 3.1, 1e-9);
}

- (void)testConfigurationUsesPresetDefaultsForOmittedFields {
    NSData *data = [@"{\"format\":\"DoubleSlitLabConfiguration\",\"version\":1,"
                    @"\"source\":{\"preset\":\"whiteLight\"}}" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    DSExperimentParameters *loaded = [DSLabConfiguration parametersFromJSONData:data error:&error];
    XCTAssertNotNil(loaded, @"Load failed: %@", error);
    XCTAssertTrue([loaded isWhiteLight]);
    XCTAssertEqual(loaded.coherenceMode, DSCoherenceModeIncoherent);
    XCTAssertEqualWithAccuracy(loaded.wavelengthNm, 550.0, 1e-9);
    XCTAssertEqualWithAccuracy(loaded.spectralWidthNm, 300.0, 1e-9);
    XCTAssertNotNil(loaded.beamColor);
}

- (void)testConfigurationRejectsUnrelatedJSON {
    NSData *data = [@"{\"hello\":\"world\"}" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    XCTAssertNil([DSLabConfiguration parametersFromJSONData:data error:&error]);
    XCTAssertEqualObjects(error.domain, DSLabConfigurationErrorDomain);
    XCTAssertEqual(error.code, DSLabConfigurationErrorInvalidFormat);
}

- (void)testConfigurationRejectsMalformedJSON {
    NSData *data = [@"this is not json" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    XCTAssertNil([DSLabConfiguration parametersFromJSONData:data error:&error]);
    XCTAssertEqualObjects(error.domain, DSLabConfigurationErrorDomain);
    XCTAssertEqual(error.code, DSLabConfigurationErrorInvalidFormat);
}

- (void)testConfigurationRejectsUnsupportedVersion {
    NSData *data = [DSLabConfiguration JSONDataForParameters:[DSExperimentParameters defaultParameters]
                                                       error:NULL];
    NSMutableDictionary *configuration = [[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] mutableCopy];
    configuration[@"version"] = @99;
    NSData *futureData = [NSJSONSerialization dataWithJSONObject:configuration options:0 error:NULL];

    NSError *error = nil;
    XCTAssertNil([DSLabConfiguration parametersFromJSONData:futureData error:&error]);
    XCTAssertEqualObjects(error.domain, DSLabConfigurationErrorDomain);
    XCTAssertEqual(error.code, DSLabConfigurationErrorUnsupportedVersion);
}

- (void)testConfigurationRejectsInvalidValueTypes {
    NSData *data = [DSLabConfiguration JSONDataForParameters:[DSExperimentParameters defaultParameters]
                                                       error:NULL];
    NSMutableDictionary *configuration = [[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] mutableCopy];
    NSMutableDictionary *source = [configuration[@"source"] mutableCopy];
    source[@"wavelengthNm"] = @"green";
    configuration[@"source"] = source;
    NSData *invalidData = [NSJSONSerialization dataWithJSONObject:configuration options:0 error:NULL];

    NSError *error = nil;
    XCTAssertNil([DSLabConfiguration parametersFromJSONData:invalidData error:&error]);
    XCTAssertEqualObjects(error.domain, DSLabConfigurationErrorDomain);
    XCTAssertEqual(error.code, DSLabConfigurationErrorInvalidValue);
}

- (void)testConfigurationClampsOutOfRangeValues {
    NSData *data = [DSLabConfiguration JSONDataForParameters:[DSExperimentParameters defaultParameters]
                                                       error:NULL];
    NSMutableDictionary *configuration = [[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] mutableCopy];
    NSMutableDictionary *source = [configuration[@"source"] mutableCopy];
    NSMutableDictionary *aperture = [configuration[@"aperture"] mutableCopy];
    NSMutableDictionary *bench = [configuration[@"bench"] mutableCopy];
    source[@"wavelengthNm"] = @900.0;
    aperture[@"slitCount"] = @99;
    aperture[@"slitWidthUm"] = @500.0;
    aperture[@"slitPitchUm"] = @10.0;
    bench[@"screenDistanceM"] = @100.0;
    configuration[@"source"] = source;
    configuration[@"aperture"] = aperture;
    configuration[@"bench"] = bench;
    NSData *outOfRangeData = [NSJSONSerialization dataWithJSONObject:configuration options:0 error:NULL];

    NSError *error = nil;
    DSExperimentParameters *loaded = [DSLabConfiguration parametersFromJSONData:outOfRangeData error:&error];
    XCTAssertNotNil(loaded, @"Load failed: %@", error);
    XCTAssertEqual(loaded.slitCount, (NSUInteger)8);
    XCTAssertLessThanOrEqual(loaded.wavelengthNm, 780.0);
    XCTAssertLessThanOrEqual(loaded.slitWidthUm, 200.0);
    XCTAssertGreaterThan(loaded.slitPitchUm, loaded.slitWidthUm);
    XCTAssertLessThanOrEqual(loaded.screenDistanceM, 5.0);
}

@end
