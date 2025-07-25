//
//  FTAppLaunchTracker.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import "FTSDKCompat.h"
#if FT_HAS_UIKIT
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif
#import <sys/sysctl.h>
#import "FTAppLaunchTracker.h"
#import "FTAppLifeCycle.h"
#import "FTLog+Private.h"
#import "NSDate+FTUtil.h"
#import "FTDateUtil.h"

#define COLD_START_TIME_THRESHOLD 30

static CFTimeInterval FTLoadDate = 0.0;
static CFTimeInterval ApplicationRespondedTime = 0.0;
static BOOL isActivePrewarm = NO;
static BOOL AppRelaunched = NO;

static CFTimeInterval processStartTime(NSTimeInterval now) {
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc kp;
    NSTimeInterval startTime = now;
    size_t len = sizeof(kp);
    int res = sysctl(mib, 4, &kp, &len, NULL, 0);
    if (res == 0) {
        struct timeval startTimeval = kp.kp_proc.p_un.__p_starttime;
        startTime = startTimeval.tv_sec + startTimeval.tv_usec / 1e6;
        startTime -= kCFAbsoluteTimeIntervalSince1970;
    }
    return startTime;
}

@interface FTAppLaunchTracker()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) NSDate *launchTime;
@property (nonatomic, assign) uint64_t launchTimeSystemTimestamp;
@end


@implementation FTAppLaunchTracker{
    BOOL _applicationDidEnterBackground;
}
@dynamic processStartTime;

+ (void)load{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    FTLoadDate = processStartTime(now);
    isActivePrewarm = [[NSProcessInfo processInfo].environment[@"ActivePrewarm"] isEqual:@"1"];
    NSNotificationCenter * __weak center = NSNotificationCenter.defaultCenter;
#if TARGET_OS_OSX
    id __block token = [center
                        addObserverForName:NSApplicationDidBecomeActiveNotification
                        object:[NSApplication sharedApplication]
                        queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *_){
        ApplicationRespondedTime = CFAbsoluteTimeGetCurrent();
        [center removeObserver:token];
        token = nil;
    }];
#else
    id __block __unused token = [center
                        addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                        queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *_){
        ApplicationRespondedTime = CFAbsoluteTimeGetCurrent();
        [center removeObserver:token];
        token = nil;
    }];
#endif
}
+(NSTimeInterval)processStartTime{
    return FTLoadDate;
}
- (instancetype)initWithDelegate:(nullable id)delegate{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        _launchTime = FTDateUtil.date;
        _launchTimeSystemTimestamp = FTDateUtil.systemTime;
        //ApplicationRespondedTime > 0 to determine if UIApplicationDidBecomeActiveNotification notification has been received before, record cold start
        if (ApplicationRespondedTime>0) {
            [self appColdStartEvent];
        }
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}
- (void)appColdStartEvent{
    AppRelaunched = YES;
    CFTimeInterval launchEnd = ApplicationRespondedTime;
    if (launchEnd == 0.0) {
        launchEnd = CFAbsoluteTimeGetCurrent();
    }
    if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppColdStart:duration:isPreWarming:)]) {
        double duration = launchEnd - FTLoadDate;
        NSDate *launchDate = [NSDate dateWithTimeIntervalSinceReferenceDate:FTLoadDate];
        BOOL isPreWarming = [self isActivePrewarmAvailable] && (isActivePrewarm || duration > COLD_START_TIME_THRESHOLD);
        [self.delegate ftAppColdStart:launchDate duration:[NSNumber numberWithLongLong:duration * 1e9] isPreWarming:isPreWarming];
    }
}
- (void)applicationWillEnterForeground{
    if (AppRelaunched){
        self.launchTime = FTDateUtil.date;
        self.launchTimeSystemTimestamp = FTDateUtil.systemTime;
    }
}
- (void)applicationDidBecomeActive{
    @try {
        if(!AppRelaunched){
            [self appColdStartEvent];
        }else if (_applicationDidEnterBackground) {
            NSNumber *duration = @(FTDateUtil.systemTime - self.launchTimeSystemTimestamp);
            if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppHotStart:duration:)]) {
                [self.delegate ftAppHotStart:self.launchTime duration:duration];
            }
            _applicationDidEnterBackground = NO;
        }
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"exception %@",exception);
    }
}
- (void)applicationDidEnterBackground{
    _applicationDidEnterBackground = YES;
}
- (BOOL)isActivePrewarmAvailable{
#    if FT_IOS
    // User data shows that iOS 14 app launches also have prewarming, which contradicts Apple's documentation that support starts from iOS 15.
    if (@available(iOS 14, *)) {
        return YES;
    } else {
        return NO;
    }
#    else
    return NO;
#    endif
}
-(void)dealloc{
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}
@end
