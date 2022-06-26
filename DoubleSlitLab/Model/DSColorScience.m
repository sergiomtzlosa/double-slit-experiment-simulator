#import "DSColorScience.h"
#import <math.h>

static double DSClamp(double value, double low, double high) {
    return value < low ? low : (value > high ? high : value);
}

typedef struct {
    double wavelength;
    double x;
    double y;
    double z;
} DSCieSample;

// CIE 1931 2° standard observer, 5 nm tabulation (380–780 nm). Linear
// interpolation gives smooth, accurate colour for arbitrary laser wavelengths.
static const DSCieSample DSCieTable[] = {
    {380, 0.001368000, 0.000039000, 0.006450001},
    {385, 0.002236000, 0.000064000, 0.010549990},
    {390, 0.004243000, 0.000120000, 0.020050010},
    {395, 0.007650000, 0.000217000, 0.036210000},
    {400, 0.014310000, 0.000396000, 0.067850010},
    {405, 0.023190000, 0.000640000, 0.110200000},
    {410, 0.043510000, 0.001210000, 0.207400000},
    {415, 0.077630000, 0.002180000, 0.371300000},
    {420, 0.134380000, 0.004000000, 0.645600000},
    {425, 0.214770000, 0.007300000, 1.039050100},
    {430, 0.283900000, 0.011600000, 1.385600000},
    {435, 0.328500000, 0.016840000, 1.622960000},
    {440, 0.348280000, 0.023000000, 1.747060000},
    {445, 0.348060000, 0.029800000, 1.782600000},
    {450, 0.336200000, 0.038000000, 1.772110000},
    {455, 0.318700000, 0.048000000, 1.744100000},
    {460, 0.290800000, 0.060000000, 1.669200000},
    {465, 0.251100000, 0.073900000, 1.528100000},
    {470, 0.195360000, 0.090980000, 1.287640000},
    {475, 0.142100000, 0.112600000, 1.041900000},
    {480, 0.095640000, 0.139020000, 0.812950100},
    {485, 0.057950010, 0.169300000, 0.616200000},
    {490, 0.032010000, 0.208020000, 0.465180000},
    {495, 0.014700000, 0.258600000, 0.353300000},
    {500, 0.004900000, 0.323000000, 0.272000000},
    {505, 0.002400000, 0.407300000, 0.212300000},
    {510, 0.009300000, 0.503000000, 0.158200000},
    {515, 0.029100000, 0.608200000, 0.111700000},
    {520, 0.063270000, 0.710000000, 0.078249990},
    {525, 0.109600000, 0.793200000, 0.057250010},
    {530, 0.165500000, 0.862000000, 0.042160000},
    {535, 0.225749900, 0.914850100, 0.029840000},
    {540, 0.290400000, 0.954000000, 0.020300000},
    {545, 0.359700000, 0.980300000, 0.013400000},
    {550, 0.433449900, 0.994950100, 0.008749999},
    {555, 0.512050100, 1.000000000, 0.005749999},
    {560, 0.594500000, 0.995000000, 0.003900000},
    {565, 0.678400000, 0.978600000, 0.002749999},
    {570, 0.762100000, 0.952000000, 0.002100000},
    {575, 0.842500000, 0.915400000, 0.001800000},
    {580, 0.916300000, 0.870000000, 0.001650001},
    {585, 0.978600000, 0.816300000, 0.001400000},
    {590, 1.026300000, 0.757000000, 0.001100000},
    {595, 1.056700000, 0.694900000, 0.001000000},
    {600, 1.062200000, 0.631000000, 0.000800000},
    {605, 1.045600000, 0.566800000, 0.000600000},
    {610, 1.002600000, 0.503000000, 0.000340000},
    {615, 0.938400000, 0.441200000, 0.000240000},
    {620, 0.854449900, 0.381000000, 0.000190000},
    {625, 0.751400000, 0.321000000, 0.000100000},
    {630, 0.642400000, 0.265000000, 0.000050000},
    {635, 0.541900000, 0.217000000, 0.000030000},
    {640, 0.447900000, 0.175000000, 0.000020000},
    {645, 0.360800000, 0.138200000, 0.000010000},
    {650, 0.283500000, 0.107000000, 0.000000000},
    {655, 0.218700000, 0.081600000, 0.000000000},
    {660, 0.164900000, 0.061000000, 0.000000000},
    {665, 0.121200000, 0.044580000, 0.000000000},
    {670, 0.087400000, 0.032000000, 0.000000000},
    {675, 0.063600000, 0.023200000, 0.000000000},
    {680, 0.046770000, 0.017000000, 0.000000000},
    {685, 0.032900000, 0.011920000, 0.000000000},
    {690, 0.022700000, 0.008210000, 0.000000000},
    {695, 0.015840000, 0.005723000, 0.000000000},
    {700, 0.011359160, 0.004102000, 0.000000000},
    {705, 0.008110916, 0.002929000, 0.000000000},
    {710, 0.005790346, 0.002091000, 0.000000000},
    {715, 0.004109457, 0.001484000, 0.000000000},
    {720, 0.002899327, 0.001047000, 0.000000000},
    {725, 0.002049190, 0.000740000, 0.000000000},
    {730, 0.001439971, 0.000520000, 0.000000000},
    {735, 0.000999949, 0.000361100, 0.000000000},
    {740, 0.000690079, 0.000249200, 0.000000000},
    {745, 0.000476021, 0.000171900, 0.000000000},
    {750, 0.000332301, 0.000120000, 0.000000000},
    {755, 0.000234826, 0.000084800, 0.000000000},
    {760, 0.000166151, 0.000060000, 0.000000000},
    {765, 0.000117413, 0.000042400, 0.000000000},
    {770, 0.000083075, 0.000030000, 0.000000000},
    {775, 0.000058707, 0.000021200, 0.000000000},
    {780, 0.000041510, 0.000014990, 0.000000000},
};

static const size_t DSCieTableCount = sizeof(DSCieTable) / sizeof(DSCieTable[0]);

DSXYZColor DSXYZForWavelength(double wavelengthNm) {
    double w = DSClamp(wavelengthNm, 380.0, 780.0);
    double position = (w - 380.0) / 5.0;
    size_t lower = (size_t)floor(position);
    if (lower >= DSCieTableCount - 1) {
        lower = DSCieTableCount - 2;
    }
    size_t upper = lower + 1;
    double t = position - (double)lower;
    DSXYZColor c;
    c.x = DSCieTable[lower].x + t * (DSCieTable[upper].x - DSCieTable[lower].x);
    c.y = DSCieTable[lower].y + t * (DSCieTable[upper].y - DSCieTable[lower].y);
    c.z = DSCieTable[lower].z + t * (DSCieTable[upper].z - DSCieTable[lower].z);
    return c;
}

void DSXYZToLinearSRGB(DSXYZColor xyz, double *r, double *g, double *b) {
    double rr =  3.2406 * xyz.x - 1.5372 * xyz.y - 0.4986 * xyz.z;
    double gg = -0.9689 * xyz.x + 1.8758 * xyz.y + 0.0415 * xyz.z;
    double bb =  0.0557 * xyz.x - 0.2040 * xyz.y + 1.0570 * xyz.z;
    if (r) *r = fmax(0.0, rr);
    if (g) *g = fmax(0.0, gg);
    if (b) *b = fmax(0.0, bb);
}

double DSSRGBEncode(double linearComponent) {
    double c = DSClamp(linearComponent, 0.0, 1.0);
    if (c <= 0.0031308) {
        return 12.92 * c;
    }
    return 1.055 * pow(c, 1.0 / 2.4) - 0.055;
}

NSColor *DSColorFromXYZ(DSXYZColor xyz) {
    double r = 0.0, g = 0.0, b = 0.0;
    DSXYZToLinearSRGB(xyz, &r, &g, &b);
    double maxComponent = fmax(r, fmax(g, b));
    if (maxComponent < 1e-9) {
        return [NSColor colorWithSRGBRed:0.6 green:0.6 blue:0.65 alpha:1.0];
    }
    r /= maxComponent;
    g /= maxComponent;
    b /= maxComponent;
    return [NSColor colorWithSRGBRed:DSSRGBEncode(r)
                               green:DSSRGBEncode(g)
                                blue:DSSRGBEncode(b)
                               alpha:1.0];
}

NSColor *DSColorForWavelength(double wavelengthNm) {
    return DSColorFromXYZ(DSXYZForWavelength(wavelengthNm));
}

double DSPlanckRelative(double wavelengthNm, double kelvin) {
    // Relative Planck spectral radiance. Absolute scale is irrelevant because
    // the spectrum is normalised before use.
    const double h = 6.62607015e-34;
    const double c = 2.99792458e8;
    const double kB = 1.380649e-23;
    double lambdaM = wavelengthNm * 1e-9;
    double exponent = (h * c) / (lambdaM * kB * kelvin);
    if (exponent > 700.0) {
        return 0.0;
    }
    double denominator = expm1(exponent);
    if (denominator <= 0.0) {
        return 0.0;
    }
    return 1.0 / (pow(lambdaM, 5.0) * denominator);
}

NSColor *DSColorForWhiteLight(void) {
    DSXYZColor sum = {0.0, 0.0, 0.0};
    for (double nm = 380.0; nm <= 780.0; nm += 2.0) {
        double weight = DSPlanckRelative(nm, 6500.0);
        DSXYZColor c = DSXYZForWavelength(nm);
        sum.x += c.x * weight;
        sum.y += c.y * weight;
        sum.z += c.z * weight;
    }
    return DSColorFromXYZ(sum);
}

double DSWavelengthForHue(double hue) {
    // Hues of the spectral locus in sRGB, derived from the CIE tabulation above.
    // Red and green are out of sRGB gamut and clamp to pure primaries, hence the
    // plateaus at the ends. Hues in the purple gap map to the nearest spectral
    // colour (violet or red).
    typedef struct { double h; double nm; } Anchor;
    static const Anchor anchors[] = {
        {0.000, 650.0},
        {0.046, 600.0},
        {0.080, 590.0},
        {0.118, 580.0},
        {0.170, 570.0},
        {0.235, 560.0},
        {0.333, 530.0},
        {0.382, 510.0},
        {0.439, 500.0},
        {0.512, 490.0},
        {0.579, 480.0},
        {0.638, 470.0},
        {0.683, 460.0},
        {0.718, 450.0},
        {0.741, 410.0}
    };
    double h = hue - floor(hue);
    const size_t count = sizeof(anchors) / sizeof(anchors[0]);

    // Hues between the violet and red ends are non-spectral purples. Snap to
    // whichever spectral endpoint is closer rather than interpolating across
    // the hue wheel (which would otherwise run through green).
    if (h >= anchors[count - 1].h) {
        double violetDistance = h - anchors[count - 1].h;
        double redDistance = 1.0 - h;
        return violetDistance <= redDistance ? anchors[count - 1].nm : 650.0;
    }

    for (size_t i = 1; i < count; i++) {
        if (h <= anchors[i].h) {
            double span = anchors[i].h - anchors[i - 1].h;
            double t = span > 0.0 ? (h - anchors[i - 1].h) / span : 0.0;
            return anchors[i - 1].nm + t * (anchors[i].nm - anchors[i - 1].nm);
        }
    }
    return 650.0;
}
