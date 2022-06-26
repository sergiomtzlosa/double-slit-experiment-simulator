#import "DSPhysicsEngine.h"
#import "DSColorScience.h"
#import <math.h>

#define DS_MAX_SPECTRAL_SAMPLES 96

typedef struct {
    double wavelengthNm;
    double weight;
    DSXYZColor xyz;
} DSSpectralSample;

DSPhysicsParameters DSPhysicsParametersMake(double wavelengthNm,
                                            double spectralWidthNm,
                                            BOOL coherent,
                                            BOOL whiteLight,
                                            NSUInteger slitCount,
                                            double slitWidthM,
                                            double slitLengthM,
                                            double slitPitchM,
                                            double screenDistanceM) {
    DSPhysicsParameters p;
    p.wavelengthNm = wavelengthNm;
    p.spectralWidthNm = spectralWidthNm;
    p.coherent = coherent;
    p.whiteLight = whiteLight;
    p.slitCount = slitCount;
    p.slitWidthM = slitWidthM;
    p.slitLengthM = slitLengthM;
    p.slitPitchM = slitPitchM;
    p.screenDistanceM = screenDistanceM;
    return p;
}

static double DSClamp(double value, double low, double high) {
    return value < low ? low : (value > high ? high : value);
}

static double DSSinc(double argument) {
    if (fabs(argument) < 1e-9) {
        return 1.0;
    }
    return sin(argument) / argument;
}

double DSSingleSlitFactor(double sinTheta, double wavelengthNm, double slitWidthM) {
    if (slitWidthM <= 0.0) {
        return 1.0;
    }
    double wavelengthM = wavelengthNm * 1e-9;
    double alpha = M_PI * slitWidthM * sinTheta / wavelengthM;
    double s = DSSinc(alpha);
    return s * s;
}

double DSInterferenceFactor(double sinTheta,
                            double wavelengthNm,
                            NSUInteger slitCount,
                            double slitPitchM) {
    if (slitCount <= 1 || slitPitchM <= 0.0) {
        return 1.0;
    }
    double wavelengthM = wavelengthNm * 1e-9;
    double beta = M_PI * slitPitchM * sinTheta / wavelengthM;
    double sinBeta = sin(beta);
    if (fabs(sinBeta) < 1e-8) {
        return 1.0;
    }
    double numerator = sin((double)slitCount * beta);
    double denominator = (double)slitCount * sinBeta;
    double factor = numerator / denominator;
    return factor * factor;
}

static double DSSlitLengthFactor(double sinPhi, double wavelengthNm, double slitLengthM) {
    if (slitLengthM <= 0.0) {
        return 1.0;
    }
    double wavelengthM = wavelengthNm * 1e-9;
    double argument = M_PI * slitLengthM * sinPhi / wavelengthM;
    double s = DSSinc(argument);
    return s * s;
}

double DSIntensityForWavelength(const DSPhysicsParameters *parameters,
                                double wavelengthNm,
                                double xMeters,
                                double yMeters) {
    if (!parameters) {
        return 0.0;
    }
    double distance = fmax(parameters->screenDistanceM, 1e-6);
    double sinTheta = xMeters / sqrt(xMeters * xMeters + distance * distance);
    double sinPhi = yMeters / sqrt(yMeters * yMeters + distance * distance);

    double envelope = DSSingleSlitFactor(sinTheta, wavelengthNm, parameters->slitWidthM);
    double vertical = DSSlitLengthFactor(sinPhi, wavelengthNm, parameters->slitLengthM);
    if (parameters->coherent) {
        double grating = DSInterferenceFactor(sinTheta,
                                              wavelengthNm,
                                              parameters->slitCount,
                                              parameters->slitPitchM);
        return envelope * grating * vertical;
    }
    return envelope * vertical;
}

static int DSBuildSpectrum(const DSPhysicsParameters *parameters,
                           DSSpectralSample *samples,
                           int maximumSamples) {
    double totalWeight = 0.0;
    int count = 0;

    if (parameters->whiteLight) {
        for (double nm = 380.0; nm <= 780.0 && count < maximumSamples; nm += 10.0) {
            double weight = DSPlanckRelative(nm, 6500.0);
            samples[count].wavelengthNm = nm;
            samples[count].weight = weight;
            totalWeight += weight;
            count++;
        }
    } else {
        double center = DSClamp(parameters->wavelengthNm, 380.0, 780.0);
        double fwhm = fmax(parameters->spectralWidthNm, 0.001);
        if (fwhm < 0.02) {
            samples[0].wavelengthNm = center;
            samples[0].weight = 1.0;
            totalWeight = 1.0;
            count = 1;
        } else {
            double sigma = fwhm / 2.354820045;
            double low = fmax(380.0, center - 4.0 * sigma);
            double high = fmin(780.0, center + 4.0 * sigma);
            const int sampleCount = 41;
            for (int i = 0; i < sampleCount && count < maximumSamples; i++) {
                double t = (double)i / (double)(sampleCount - 1);
                double nm = low + t * (high - low);
                double delta = (nm - center) / sigma;
                double weight = exp(-0.5 * delta * delta);
                if (weight < 1e-8) {
                    continue;
                }
                samples[count].wavelengthNm = nm;
                samples[count].weight = weight;
                totalWeight += weight;
                count++;
            }
            if (count == 0) {
                samples[0].wavelengthNm = center;
                samples[0].weight = 1.0;
                totalWeight = 1.0;
                count = 1;
            }
        }
    }

    if (totalWeight <= 0.0) {
        return 0;
    }
    for (int i = 0; i < count; i++) {
        samples[i].weight /= totalWeight;
        samples[i].xyz = DSXYZForWavelength(samples[i].wavelengthNm);
    }
    return count;
}

static double DSIntegratedIntensity(const DSPhysicsParameters *parameters,
                                    const DSSpectralSample *samples,
                                    int sampleCount,
                                    double xMeters,
                                    double yMeters) {
    double total = 0.0;
    for (int i = 0; i < sampleCount; i++) {
        total += samples[i].weight * DSIntensityForWavelength(parameters,
                                                              samples[i].wavelengthNm,
                                                              xMeters,
                                                              yMeters);
    }
    return total;
}

static double DSFirstInterferenceMinimumXMeters(const DSPhysicsParameters *parameters) {
    if (!parameters->coherent || parameters->slitCount < 2) {
        return 0.0;
    }
    double wavelengthM = parameters->wavelengthNm * 1e-9;
    double sinTheta = wavelengthM / ((double)parameters->slitCount * parameters->slitPitchM);
    if (sinTheta <= 0.0 || sinTheta >= 1.0) {
        return 0.0;
    }
    double angle = asin(sinTheta);
    return parameters->screenDistanceM * tan(angle);
}

DSPatternMetrics DSComputeMetrics(const DSPhysicsParameters *parameters) {
    DSPatternMetrics metrics;
    memset(&metrics, 0, sizeof(metrics));
    if (!parameters) {
        return metrics;
    }

    double centerNm = parameters->whiteLight ? 550.0 : parameters->wavelengthNm;
    double wavelengthM = centerNm * 1e-9;
    double distance = fmax(parameters->screenDistanceM, 0.01);
    double width = fmax(parameters->slitWidthM, 1e-9);
    double length = fmax(parameters->slitLengthM, 1e-9);
    double pitch = fmax(parameters->slitPitchM, 1e-9);
    NSUInteger count = MAX((NSUInteger)1, parameters->slitCount);

    double fringeMeters = wavelengthM * distance / pitch;
    double envelopeFirstZeroMeters = wavelengthM * distance / width;
    double verticalFirstZeroMeters = wavelengthM * distance / length;

    metrics.fringeSpacingMm = (parameters->coherent && count > 1) ? fringeMeters * 1000.0 : 0.0;
    metrics.centralLobeWidthMm = 2.0 * envelopeFirstZeroMeters * 1000.0;
    metrics.verticalLobeHeightMm = 2.0 * verticalFirstZeroMeters * 1000.0;
    double linewidth = fmax(parameters->spectralWidthNm, 0.001);
    metrics.coherenceLengthMm = (parameters->whiteLight ? 0.0
                                                        : (centerNm * centerNm / linewidth) / 1e6);

    double xHalfMeters;
    if (parameters->coherent && count > 1) {
        xHalfMeters = 4.0 * fringeMeters;
    } else {
        xHalfMeters = 1.20 * envelopeFirstZeroMeters;
    }
    double yHalfMeters = 1.15 * verticalFirstZeroMeters;
    metrics.xHalfRangeMm = DSClamp(xHalfMeters * 1000.0, 0.0005, 5000.0);
    metrics.yHalfRangeMm = DSClamp(yHalfMeters * 1000.0, 0.0005, 5000.0);

    if (parameters->coherent && count > 1) {
        DSSpectralSample samples[DS_MAX_SPECTRAL_SAMPLES];
        int sampleCount = DSBuildSpectrum(parameters, samples, DS_MAX_SPECTRAL_SAMPLES);
        if (sampleCount > 0) {
            double atCenter = DSIntegratedIntensity(parameters, samples, sampleCount, 0.0, 0.0);
            double xMin = DSFirstInterferenceMinimumXMeters(parameters);
            double atMinimum = DSIntegratedIntensity(parameters, samples, sampleCount, xMin, 0.0);
            if (atCenter + atMinimum > 1e-12) {
                metrics.visibility = DSClamp((atCenter - atMinimum) / (atCenter + atMinimum), 0.0, 1.0);
            }
        }
    }
    return metrics;
}

@implementation DSPatternResult
@end

static DSPatternResult *DSRenderPatternInternal(const DSPhysicsParameters *parameters,
                                                 size_t width,
                                                 size_t height,
                                                 double xHalfRangeMm,
                                                 double yHalfRangeMm) {
    if (!parameters) {
        return nil;
    }
    if (width < 64) width = 64;
    if (height < 64) height = 64;
    if (width > 1600) width = 1600;
    if (height > 1200) height = 1200;

    DSPatternMetrics metrics = DSComputeMetrics(parameters);
    if (isfinite(xHalfRangeMm) && xHalfRangeMm > 0.0) {
        metrics.xHalfRangeMm = DSClamp(xHalfRangeMm, 0.0005, 5000.0);
    }
    if (isfinite(yHalfRangeMm) && yHalfRangeMm > 0.0) {
        metrics.yHalfRangeMm = DSClamp(yHalfRangeMm, 0.0005, 5000.0);
    }
    double xHalf = fmax(metrics.xHalfRangeMm, 0.0005) * 1e-3;
    double yHalf = fmax(metrics.yHalfRangeMm, 0.0005) * 1e-3;

    DSSpectralSample samples[DS_MAX_SPECTRAL_SAMPLES];
    int sampleCount = DSBuildSpectrum(parameters, samples, DS_MAX_SPECTRAL_SAMPLES);
    if (sampleCount <= 0) {
        return nil;
    }

    size_t pixelCount = width * height;
    float *accum = calloc(pixelCount * 3, sizeof(float));
    float *profile = calloc(width, sizeof(float));
    double *xFactors = calloc(width, sizeof(double));
    double *yFactors = calloc(height, sizeof(double));
    double *sinTheta = calloc(width, sizeof(double));
    double *sinPhi = calloc(height, sizeof(double));
    if (!accum || !profile || !xFactors || !yFactors || !sinTheta || !sinPhi) {
        free(accum); free(profile); free(xFactors); free(yFactors); free(sinTheta); free(sinPhi);
        return nil;
    }

    double distance = fmax(parameters->screenDistanceM, 0.01);
    for (size_t x = 0; x < width; x++) {
        double physicalX = -xHalf + ((double)x + 0.5) / (double)width * (2.0 * xHalf);
        sinTheta[x] = physicalX / sqrt(physicalX * physicalX + distance * distance);
    }
    for (size_t y = 0; y < height; y++) {
        double physicalY = yHalf - ((double)y + 0.5) / (double)height * (2.0 * yHalf);
        sinPhi[y] = physicalY / sqrt(physicalY * physicalY + distance * distance);
    }

    for (int s = 0; s < sampleCount; s++) {
        double wavelengthNm = samples[s].wavelengthNm;
        double weight = samples[s].weight;
        double wr = weight * samples[s].xyz.x;
        double wg = weight * samples[s].xyz.y;
        double wb = weight * samples[s].xyz.z;

        for (size_t x = 0; x < width; x++) {
            double envelope = DSSingleSlitFactor(sinTheta[x], wavelengthNm, parameters->slitWidthM);
            double grating = 1.0;
            if (parameters->coherent) {
                grating = DSInterferenceFactor(sinTheta[x],
                                               wavelengthNm,
                                               parameters->slitCount,
                                               parameters->slitPitchM);
            }
            xFactors[x] = envelope * grating;
        }
        for (size_t y = 0; y < height; y++) {
            yFactors[y] = DSSlitLengthFactor(sinPhi[y], wavelengthNm, parameters->slitLengthM);
        }

        for (size_t x = 0; x < width; x++) {
            profile[x] += (float)(wg * xFactors[x]);
        }

        for (size_t y = 0; y < height; y++) {
            double yf = yFactors[y];
            size_t base = y * width * 3;
            for (size_t x = 0; x < width; x++) {
                double value = xFactors[x] * yf;
                accum[base + x * 3 + 0] += (float)(wr * value);
                accum[base + x * 3 + 1] += (float)(wg * value);
                accum[base + x * 3 + 2] += (float)(wb * value);
            }
        }
    }

    double maxY = 0.0;
    for (size_t i = 0; i < pixelCount; i++) {
        double yValue = accum[i * 3 + 1];
        if (yValue > maxY) {
            maxY = yValue;
        }
    }
    double maxProfile = 0.0;
    for (size_t x = 0; x < width; x++) {
        if (profile[x] > maxProfile) {
            maxProfile = profile[x];
        }
    }

    unsigned char *rgba = calloc(pixelCount * 4, sizeof(unsigned char));
    if (!rgba) {
        free(accum); free(profile); free(xFactors); free(yFactors); free(sinTheta); free(sinPhi);
        return nil;
    }
    double exposure = (maxY > 1e-12) ? (1.0 / maxY) : 0.0;
    for (size_t i = 0; i < pixelCount; i++) {
        double X = accum[i * 3 + 0] * exposure;
        double Y = accum[i * 3 + 1] * exposure;
        double Z = accum[i * 3 + 2] * exposure;
        DSXYZColor xyz = {X, Y, Z};
        double r = 0.0, g = 0.0, b = 0.0;
        DSXYZToLinearSRGB(xyz, &r, &g, &b);
        r = fmin(1.0, fmax(0.0, r));
        g = fmin(1.0, fmax(0.0, g));
        b = fmin(1.0, fmax(0.0, b));
        rgba[i * 4 + 0] = (unsigned char)lrint(DSSRGBEncode(r) * 255.0);
        rgba[i * 4 + 1] = (unsigned char)lrint(DSSRGBEncode(g) * 255.0);
        rgba[i * 4 + 2] = (unsigned char)lrint(DSSRGBEncode(b) * 255.0);
        rgba[i * 4 + 3] = 255;
    }

    if (maxProfile > 1e-12) {
        for (size_t x = 0; x < width; x++) {
            profile[x] = (float)(profile[x] / maxProfile);
        }
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    NSData *pixelData = [NSData dataWithBytesNoCopy:rgba length:pixelCount * 4 freeWhenDone:YES];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixelData);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGBitmapByteOrder32Big |
                              (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    CGImageRef cgImage = CGImageCreate(width,
                                      height,
                                      8,
                                      32,
                                      width * 4,
                                      colorSpace,
                                      bitmapInfo,
                                      provider,
                                      NULL,
                                      false,
                                      kCGRenderingIntentDefault);
    DSPatternResult *result = [[DSPatternResult alloc] init];
    result.pixelWidth = width;
    result.pixelHeight = height;
    result.metrics = metrics;
    result.profileLength = width;
    result.profile = [NSData dataWithBytes:profile length:width * sizeof(float)];
    if (cgImage) {
        result.image = [[NSImage alloc] initWithCGImage:cgImage size:NSMakeSize((CGFloat)width, (CGFloat)height)];
        CGImageRelease(cgImage);
    }
    if (provider) CGDataProviderRelease(provider);
    if (colorSpace) CGColorSpaceRelease(colorSpace);

    free(accum);
    free(profile);
    free(xFactors);
    free(yFactors);
    free(sinTheta);
    free(sinPhi);
    return result;
}

DSPatternResult *DSRenderPattern(const DSPhysicsParameters *parameters,
                                 size_t width,
                                 size_t height) {
    return DSRenderPatternInternal(parameters, width, height, 0.0, 0.0);
}

DSPatternResult *DSRenderPatternInDisplayRange(const DSPhysicsParameters *parameters,
                                               size_t width,
                                               size_t height,
                                               double xHalfRangeMm,
                                               double yHalfRangeMm) {
    return DSRenderPatternInternal(parameters, width, height, xHalfRangeMm, yHalfRangeMm);
}
