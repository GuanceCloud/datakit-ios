//
//  FTRumSessionReplay.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTRumSessionReplay.h"
#import "FTSessionReplayTouches.h"
#import "FTNetworkManager.h"
#import "FTImageRequest.h"
#import "FTLog.h"
#import "FTGlobalRumManager.h"
#import "FTCompression.h"
#import "FTThreadDispatchManager.h"
#import "FTSessionReplayUploader.h"
#import "FTWindowObserver.h"
#import "FTRecorder.h"
#import "FTViewAttributes.h"
#import "FTSRTextObfuscatingFactory.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
@interface FTRumSessionReplay ()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) FTSessionReplayTouches *touches;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) BOOL isSampled;
@property (nonatomic, strong) FTSessionReplayUploader *uploader;
@property (nonatomic, strong) FTWindowObserver *windowObserver;
@property (nonatomic, assign) FTSRPrivacy privacy;
@property (nonatomic, strong) FTRecorder *windowRecorder;
@property (nonatomic, strong) NSDictionary *lastRUMContext;
@end
@implementation FTRumSessionReplay
-(instancetype)init{
    self = [super init];
    if(self){
        _windowObserver = [[FTWindowObserver alloc]init];
        _touches = [[FTSessionReplayTouches alloc]initWithWindowObserver:_windowObserver];
        _uploader = [[FTSessionReplayUploader alloc]init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextChange:) name:FTRumContextDidChangeNotification object:nil];
    }
    return self;
}
- (void)contextChange:(NSNotification *)notification{
    NSDictionary *context = notification.userInfo;
    if(self.lastRUMContext){
        if(![context isEqualToDictionary:self.lastRUMContext]&& ![context[FT_RUM_KEY_SESSION_ID] isEqualToString:self.lastRUMContext[FT_RUM_KEY_SESSION_ID]]){
            BOOL isSampled = [FTBaseInfoHandler randomSampling:self.sampleRate];
            if (isSampled) {
                [self start];
            } else {
                [self stop];
            }
            _isSampled = isSampled;
        }
    }
    self.lastRUMContext = context;
}
-(FTRecorder *)windowRecorder{
    if(!_windowRecorder){
        _windowRecorder = [[FTRecorder alloc]initWithWindowObserver:_windowObserver];
    }
    
    return _windowRecorder;
}
-(void)start{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        if(self.timer){
            return;
        }
        __weak typeof(self) weakSelf = self;
        self.timer = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [weakSelf captureNextRecord];
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }];
}
- (void)stop{
    [FTThreadDispatchManager performBlockDispatchMainAsync:^{
        if(self.timer){
            [self.timer invalidate];
            self.timer = nil;
        }
    }];
}
- (void)captureNextRecord{
    NSString *viewID = self.lastRUMContext[FT_KEY_VIEW_ID];
    if (!viewID) {
        return;
    }
    FTSRContext *context = [[FTSRContext alloc]init];
    context.privacy = [[FTSRTextObfuscatingFactory alloc]initWithPrivacy:self.privacy];
    context.sessionID = self.lastRUMContext[FT_RUM_KEY_SESSION_ID];
    context.viewID = self.lastRUMContext[FT_KEY_VIEW_ID];
    context.applicationID = self.lastRUMContext[FT_APP_ID];
    context.date = [NSDate date];
    [self.windowRecorder taskSnapShot:context touches:[self.touches takeTouches]];
}
-(void)dealloc{
    [self stop];
}
@end
