#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    double x;
    double y;
    double z;
} DSXYZColor;

/// CIE 1931 2° colour-matching functions, interpolated from a 5 nm tabulation.
FOUNDATION_EXPORT DSXYZColor DSXYZForWavelength(double wavelengthNm);

/// Nearest spectral wavelength for an arbitrary sRGB hue (custom beam colour).
FOUNDATION_EXPORT double DSWavelengthForHue(double hue);

/// Display colour for a monochromatic source, normalised for UI visibility.
FOUNDATION_EXPORT NSColor *DSColorForWavelength(double wavelengthNm);

/// Warm-white representative colour for the broadband source.
FOUNDATION_EXPORT NSColor *DSColorForWhiteLight(void);

FOUNDATION_EXPORT NSColor *DSColorFromXYZ(DSXYZColor xyz);
FOUNDATION_EXPORT void DSXYZToLinearSRGB(DSXYZColor xyz, double *r, double *g, double *b);
FOUNDATION_EXPORT double DSSRGBEncode(double linearComponent);
FOUNDATION_EXPORT double DSPlanckRelative(double wavelengthNm, double kelvin);

NS_ASSUME_NONNULL_END
