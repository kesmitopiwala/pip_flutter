
#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

@interface PipFlutterEzDrmAssetsLoaderDelegate : NSObject

@property(readonly, nonatomic) NSURL* certificateURL;
@property(readonly, nonatomic) NSURL* licenseURL;
- (instancetype)init:(NSURL *)certificateURL withLicenseURL:(NSURL *)licenseURL;

@end
