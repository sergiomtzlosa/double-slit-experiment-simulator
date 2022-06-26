#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSPatternView : NSView
@property (nonatomic, strong, nullable) NSImage *patternImage;
@property (nonatomic, strong, nullable) NSColor *accentColor;
@property (nonatomic) BOOL shutterClosed;
@property (nonatomic) double xHalfRangeMm;
@property (nonatomic) double yHalfRangeMm;
@end

@interface DSProfileView : NSView
@property (nonatomic, strong, nullable) NSData *profileData;
@property (nonatomic) NSUInteger profileLength;
@property (nonatomic) double xHalfRangeMm;
@property (nonatomic, strong, nullable) NSColor *accentColor;
- (void)setProfileData:(nullable NSData *)data
                 count:(NSUInteger)count
          xHalfRangeMm:(double)xHalfRangeMm
            accentColor:(nullable NSColor *)accentColor;
@end

NS_ASSUME_NONNULL_END
