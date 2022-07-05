//
//  FTAppLaunchTracker.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "FTAppLaunchTracker.h"
#import "FTAppLifeCycle.h"
#import "FTLog.h"
#import "FTDateUtil.h"

static NSTimeInterval FTLoadDate = 0.0;
static NSTimeInterval ApplicationRespondedTime = 0.0;

static BOOL AppRelaunched = NO;
@interface FTAppLaunchTracker()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) NSDate *launchTime;
@end


@implementation FTAppLaunchTracker{
    BOOL _applicationDidEnterBackground;
}
+ (void)load{
    FTLoadDate = CFAbsoluteTimeGetCurrent();
    NSNotificationCenter * __weak center = NSNotificationCenter.defaultCenter;
    id __block token = [center
                        addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                        queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *_){
        ApplicationRespondedTime = CFAbsoluteTimeGetCurrent();
        [center removeObserver:token];
        token = nil;
    }];
}
- (instancetype)init{
    return [self initWithDelegate:nil];
}
- (instancetype)initWithDelegate:(nullable id)delegate{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        _launchTime = [NSDate date];
        if (ApplicationRespondedTime>0) {
            [self appColdStartEvent];
        }
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
- (void)appColdStartEvent{
    AppRelaunched = YES;
    NSTimeInterval launchEnd = ApplicationRespondedTime;
    if (launchEnd == 0.0) {
        launchEnd = CFAbsoluteTimeGetCurrent();
    }
    NSNumber *duration = [NSNumber numberWithLong:(launchEnd-FTLoadDate)*1000000000];
    if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppColdStart:)]) {
        [self.delegate ftAppColdStart:duration];
    }
}
- (void)applicationWillEnterForeground{
    if (AppRelaunched){
        self.launchTime = [NSDate date];
    }
}
- (void)applicationDidBecomeActive{
    @try {
        if(!AppRelaunched){
            [self appColdStartEvent];
        }else if (_applicationDidEnterBackground) {
            NSNumber *duration = [FTDateUtil nanosecondTimeIntervalSinceDate:self.launchTime toDate:[NSDate date]];
            if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppHotStart:)]) {
                [self.delegate ftAppHotStart:duration];
            }
        }
    }
    @catch (NSException *exception) {
        ZYErrorLog(@"exception %@",exception);
    }
}
- (void)applicationDidEnterBackground{
    _applicationDidEnterBackground = YES;
}
-(void)dealloc{
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}
@end
