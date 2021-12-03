

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import "PipFlutterTimeUtils.h"
#import "PipFlutter.h"
#import <MediaPlayer/MediaPlayer.h>

@interface PipFlutterPlugin : NSObject <FlutterPlugin, FlutterPlatformViewFactory>

@property(readonly, weak, nonatomic) NSObject<FlutterBinaryMessenger>* messenger;
@property(readonly, strong, nonatomic) NSMutableDictionary* players;
@property(readonly, strong, nonatomic) NSObject<FlutterPluginRegistrar>* registrar;

@end