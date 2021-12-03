#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

// BetterPlayerView.h
@interface PipFlutterView : UIView
@property AVPlayer *player;
@property (readonly) AVPlayerLayer *playerLayer;
@end
