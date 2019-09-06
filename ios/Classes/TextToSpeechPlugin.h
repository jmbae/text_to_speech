#import <Flutter/Flutter.h>
#import <AVFoundation/AVFoundation.h>

@interface TextToSpeechPlugin : NSObject<FlutterPlugin, AVSpeechSynthesizerDelegate>
@end
