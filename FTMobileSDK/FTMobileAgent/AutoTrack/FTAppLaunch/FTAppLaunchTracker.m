//
//  FTAppLaunchTracker.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "FTAppLaunchTracker.h"
#import "FTSwizzler.h"
#import "FTAppLifeCycle.h"
#import "FTLog.h"
#import "FTDateUtil.h"
@interface FTAppLaunchTracker()<FTAppLifeCycleDelegate>
@property (nonatomic, strong ,class) NSDate *startDate;
@property (nonatomic, strong) NSDate *launchTime;
@end
static NSDate * _startDate = nil;

@implementation FTAppLaunchTracker{
    BOOL _appRelaunched;          // App 从后台恢复
    BOOL _applicationDidEnterBackground;
}
+ (void)load{
    FTAppLaunchTracker.startDate = [NSDate date];
}
+(NSDate *)startDate{
    if (!_startDate) {
        _startDate = [NSDate date];
    }
    return _startDate;
}
+(void)setStartDate:(NSDate *)startDate{
    _startDate = startDate;
}
- (instancetype)init{
    return [self initWithDelegate:nil];
}
- (instancetype)initWithDelegate:(nullable id)delegate{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        _launchTime = [NSDate date];
        [self coldLaunch];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
static dispatch_once_t onceToken;

-(void)coldLaunch{
    NSNumber *duration = [FTDateUtil nanosecondTimeIntervalSinceDate:FTAppLaunchTracker.startDate toDate:[NSDate date]];
    _appRelaunched = YES;
    if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppColdStart:)]) {
        [self.delegate ftAppColdStart:duration];
    }
}
- (void)applicationWillEnterForeground{
    if (_appRelaunched){
        self.launchTime = [NSDate date];
    }
}
- (void)applicationDidBecomeActive{
    @try {
        if (_applicationDidEnterBackground) {
            if (!_appRelaunched) {
                return;
            }
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
    onceToken = 0;
}
@end
