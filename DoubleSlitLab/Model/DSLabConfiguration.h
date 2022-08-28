#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSExperimentParameters;

FOUNDATION_EXPORT NSString * const DSLabConfigurationErrorDomain;

typedef NS_ENUM(NSInteger, DSLabConfigurationErrorCode) {
    DSLabConfigurationErrorInvalidFormat = 1,
    DSLabConfigurationErrorUnsupportedVersion = 2,
    DSLabConfigurationErrorInvalidValue = 3,
};

/// Reads and writes the complete optical-bench state as human-readable JSON.
///
/// A configuration file records the light source, aperture, bench geometry,
/// and shutter state. Values are validated and clamped when loaded; unknown
/// top-level keys are ignored so that newer files degrade gracefully.
@interface DSLabConfiguration : NSObject

+ (NSString *)formatIdentifier;
+ (NSInteger)currentVersion;

+ (nullable NSData *)JSONDataForParameters:(DSExperimentParameters *)parameters
                                     error:(NSError **)error;

+ (nullable DSExperimentParameters *)parametersFromJSONData:(NSData *)data
                                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
