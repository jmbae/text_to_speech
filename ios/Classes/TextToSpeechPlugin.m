#import "TextToSpeechPlugin.h"

@interface TextToSpeechPlugin ()
@property(nonatomic, retain) FlutterMethodChannel *channel;

@property (nonatomic) AVSpeechSynthesizer* synthesizer;
@property (nonatomic) NSString* language;
@property (nonatomic) float rate;
@property (nonatomic) NSSet<NSString *>* languages;
@property (nonatomic) float volume;
@property (nonatomic) float pitch;
@property (nonatomic) AVSpeechSynthesisVoice* voice;

@end

@implementation TextToSpeechPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_text_to_speech"
                                     binaryMessenger:[registrar messenger]];
    TextToSpeechPlugin* instance = [[TextToSpeechPlugin alloc] initWithChannel:channel];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithChannel:(FlutterMethodChannel*) channel {
    self = [super init];
    if (self) {
        _channel = channel;
        _synthesizer = [[AVSpeechSynthesizer alloc] init];
        _synthesizer.delegate = self;
        _language = [AVSpeechSynthesisVoice currentLanguageCode];
        _rate = AVSpeechUtteranceDefaultSpeechRate;
        _volume = 1.0;
        _pitch = 1.0;
        [self setLanguages];

        @try {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
        } @catch (NSException *exception) {
            NSLog(@"%@", [exception description]);
        }
    }
    return self;
}

- (void)setLanguages {
    NSMutableSet<NSString*>* languages = [[NSMutableSet<NSString*> alloc] init];
    if (@available(iOS 9.0, *)) {
        for (AVSpeechSynthesisVoice* voice in [AVSpeechSynthesisVoice speechVoices]) {
            [languages addObject:voice.language];
        }
        _languages = [[NSSet<NSString*> alloc] initWithSet:languages];
    }
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"speak" isEqualToString:call.method]) {
        [self speakWithText:[NSString stringWithString:[call arguments]]];
    } else if ([@"setLanguage" isEqualToString:call.method]) {
        [self setLanguageWithLanguage:[NSString stringWithString:[call arguments]] withResult:result];
    } else if ([@"setSpeechRate" isEqualToString:call.method]) {
        [self setRate:[call.arguments floatValue]];
        result(@YES);
    } else if ([@"setVolume" isEqualToString:call.method]) {
        [self setVolume:[call.arguments floatValue]];
        result(@YES);
    } else if ([@"setPitch" isEqualToString:call.method]) {
        [self setPitch:[call.arguments floatValue]];
        result(@YES);
    } else if ([@"stop" isEqualToString:call.method]) {
        [self stop];
        result(@YES);
    } else if ([@"getLanguages" isEqualToString:call.method]) {
        [self getLanguagesWithResult:result];
    } else if ([@"isLanguageAvailable" isEqualToString:call.method]) {
        [self isLanguageAvailableWithLanguage:[(NSDictionary*)call.arguments objectForKey:@"language"] withResult:result];
    } else if ([@"getVoices" isEqualToString:call.method]) {
        [self getVoicesWithResult:result];
    } else if ([@"setVoice" isEqualToString:call.method]) {
        [self setVoiceWithName:[NSString stringWithString:[call arguments]] withResult:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)speakWithText:(NSString*)text {
    AVSpeechUtterance* utterance = [[AVSpeechUtterance alloc] initWithString:text];
    if (_voice != nil) {
        [utterance setVoice:_voice];
    } else {
        [utterance setVoice:[AVSpeechSynthesisVoice voiceWithLanguage:_language]];
    }
    [utterance setRate:_rate];
    [utterance setVolume:_volume];
    [utterance setPitchMultiplier:_pitch];
    [_synthesizer speakUtterance:utterance];
}

- (void)setLanguageWithLanguage:(NSString*)language withResult:(FlutterResult) result {
    if (![_languages containsObject:language]) {
        result(@NO);
    } else {
        _language = language;
        _voice = NULL;
        result(@YES);
    }
}

- (void)setRate:(float)rate {
    _rate = rate;
}

- (void)setVolume:(float)volume withResult:(FlutterResult) result  {
    if( volume >= 0.0 && volume <= 1.0) {
        _volume = volume;
        result(@YES);
    } else {
        result(@NO);
    }
}

- (void)setPitch:(float)pitch withResult:(FlutterResult) result {
    if (pitch >= 0.5 && pitch <= 2.0) {
        _pitch = pitch;
        result(@YES);
    } else {
        result(@NO);
    }
}

- (void)stop {
    [_synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

- (void)getLanguagesWithResult:(FlutterResult) result {
    result([_languages allObjects]);
}

- (void)isLanguageAvailableWithLanguage:(NSString*) language withResult:(FlutterResult) result {
    if ([_languages containsObject:language]) {
        result(@YES);
    } else {
        result(@NO);
    }
}

- (void)getVoicesWithResult:(FlutterResult) result {
    if (@available(iOS 9.0, *)) {
        NSMutableArray* voices = [[NSMutableArray alloc] init];
        for (AVSpeechSynthesisVoice* voice in [AVSpeechSynthesisVoice speechVoices]) {
            [voices addObject:voice.name];
        }
        result([NSArray arrayWithArray:voices]);
    } else {
        [self getLanguagesWithResult:result];
    }
}

- (void)setVoiceWithName:(NSString*) voiceName withResult:(FlutterResult) result {
    if (@available(iOS 9.0, *)) {
        for (AVSpeechSynthesisVoice* voice in [AVSpeechSynthesisVoice speechVoices]) {
            if([voice.name isEqualToString:voiceName]) {
                _voice = voice;
                _language = voice.name;
                result(@YES);
                return;
            }
            result(@NO);
        }
    } else {
        [self setLanguageWithLanguage: voiceName withResult: result];
    }
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    [_channel invokeMethod:@"speak.onComplete" arguments:nil];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance {
    [_channel invokeMethod:@"speak.onStart" arguments:nil];
}

@end
