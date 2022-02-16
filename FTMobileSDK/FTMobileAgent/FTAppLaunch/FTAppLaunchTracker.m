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
@property (nonatomic, strong) NSDate *launchTime;
@end
@implementation FTAppLaunchTracker{
    BOOL _appRelaunched;          // App 从后台恢复
    BOOL _applicationDidEnterBackground;
}
- (instancetype)init{
    self = [super init];
    if (self) {
        _launchTime = [NSDate date];
        [self trackFirstViewControllerStart];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
static dispatch_once_t onceToken;

- (void)trackFirstViewControllerStart{
    SEL viewWillAppearSel = @selector(viewWillAppear:);
    __weak typeof(self) weakSelf = self;

    dispatch_once(&onceToken, ^{
        
        [FTSwizzler swizzleSelector:viewWillAppearSel onClass:UIViewController.class withBlock:^{
            [weakSelf coldLaunch];
        } named:@"firstViewControllerStart"];
    });
}
-(void)coldLaunch{
    NSNumber *duration = [FTDateUtil nanosecondTimeIntervalSinceDate:self.launchTime toDate:[NSDate date]];
    _appRelaunched = YES;
    if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppColdStart:)]) {
        [self.delegate ftAppColdStart:duration];
    }
    [self unTrackFirstViewControllerStart];
}

-(void)unTrackFirstViewControllerStart{
    SEL viewWillAppearSel = @selector(viewWillAppear:);
    [FTSwizzler unswizzleSelector:viewWillAppearSel onClass:UIViewController.class named:@"firstViewControllerStart"];
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
    [self unTrackFirstViewControllerStart];
    onceToken = 0;
}
@end
