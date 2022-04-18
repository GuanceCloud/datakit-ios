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


static NSDate * FTLoadDate = nil;

@interface FTAppLaunchTracker()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) NSDate *launchTime;
@end


@implementation FTAppLaunchTracker{
    BOOL _appRelaunched;          // App 从后台恢复
    BOOL _applicationDidEnterBackground;
}
+ (void)load{
    FTLoadDate = [NSDate date];
}
- (instancetype)init{
    return [self initWithDelegate:nil];
}
- (instancetype)initWithDelegate:(nullable id)delegate{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        _launchTime = [NSDate date];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
static dispatch_once_t onceToken;

- (void)applicationWillEnterForeground{
    if (_appRelaunched){
        self.launchTime = [NSDate date];
    }
}
- (void)applicationDidBecomeActive{
    @try {
        if(!_appRelaunched){
            NSNumber *duration = [FTDateUtil nanosecondTimeIntervalSinceDate:FTLoadDate toDate:[NSDate date]];
            _appRelaunched = YES;
            if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppColdStart:)]) {
                [self.delegate ftAppColdStart:duration];
            }
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
    onceToken = 0;
}
@end
