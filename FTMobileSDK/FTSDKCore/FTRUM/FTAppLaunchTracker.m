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
#import "FTAppLaunchTracker.h"
#import "FTAppLifeCycle.h"
#import "FTLog+Private.h"
#import "NSDate+FTUtil.h"
#import "FTDateUtil.h"
#import "FTDisplayRateMonitor.h"
#import "FTConstants.h"

#define COLD_START_TIME_THRESHOLD 30
static NSDate *_sdkStartDate = nil;
static NSDate *applicationDidBecomeActive;
static NSDate *moduleInitializationTimestamp;
static NSDate *runtimeInit = nil;
static BOOL isActivePrewarm = NO;
static BOOL AppRelaunched = NO;

/**
 * Constructor priority must be bounded between 101 and 65535 inclusive, see
 * https://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/Function-Attributes.html and
 * https://gcc.gnu.org/onlinedocs/gcc-4.7.0/gcc/C_002b_002b-Attributes.html#C_002b_002b-Attributes
 * The constructor attribute causes the function to be called automatically before execution enters
 * @c main() . The lower the priority number, the sooner the constructor runs, which means 100 runs
 * before 101. As we want to be as close to @c main() as possible, we choose a high number.
 *
 */
__used __attribute__((constructor(60000))) static void
ftModuleInitializationHook(void)
{
    moduleInitializationTimestamp = [NSDate date];
}
@interface FTAppLaunchTracker()<FTAppLifeCycleDelegate>
@property (nonatomic, strong) NSDate *launchTime;
@property (nonatomic, assign) uint64_t launchTimeSystemTimestamp;
@property (nonatomic, strong) NSDate *didFinishLaunchingTimestamp;

@end


@implementation FTAppLaunchTracker{
    BOOL _applicationDidEnterBackground;
}

+ (void)load{
    runtimeInit = [NSDate date];
    
    isActivePrewarm = [[NSProcessInfo processInfo].environment[@"ActivePrewarm"] isEqual:@"1"];
   
    NSNotificationCenter * __weak center = NSNotificationCenter.defaultCenter;
#if TARGET_OS_OSX
    id __block token = [center
                        addObserverForName:NSApplicationDidBecomeActiveNotification
                        object:[NSApplication sharedApplication]
                        queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *_){
        applicationDidBecomeActive = [NSDate date];
        [center removeObserver:token];
        token = nil;
    }];
#else
    id __block __unused token = [center
                        addObserverForName:UIApplicationDidBecomeActiveNotification
                        object:nil
                        queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification *_){
        applicationDidBecomeActive = [NSDate date];
        [center removeObserver:token];
        token = nil;
    }];
#endif
}
- (instancetype)initWithDelegate:(nullable id)delegate displayMonitor:(FTDisplayRateMonitor *)displayMonitor{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        _didFinishLaunchingTimestamp = FTDateUtil.date;
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
        
        [self handleLaunchPhaseWithDisplayMonitor:displayMonitor];
    }
    return self;
}
- (void)handleLaunchPhaseWithDisplayMonitor:(FTDisplayRateMonitor *)displayMonitor {
    //applicationDidBecomeActive != nil to determine if UIApplicationDidBecomeActiveNotification notification has been received before, record cold start
    if (applicationDidBecomeActive != nil) {
        [self reportAppLaunchPhaseDuration:applicationDidBecomeActive];
    }else{
        NSDate *firstFrame = [displayMonitor firstFrameDate];
        if (firstFrame == nil) {
            [displayMonitor start];
            __weak typeof(self) weakSelf = self;
            __weak typeof(displayMonitor) weakMonitor = displayMonitor;
            displayMonitor.callBack = ^(NSDate * _Nonnull date) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [weakMonitor stop];
                [strongSelf reportAppLaunchPhaseDuration:date];
            };
        }else{
            [self reportAppLaunchPhaseDuration:firstFrame];
        }
    }
}
- (void)reportAppLaunchPhaseDuration:(NSDate *)endDate{
        AppRelaunched = YES;
        /**
         SystemInterface: processStartTimestamp - runtimeInit
         RuntimeInit:   runtimeInit -  moduleInitializationTimestamp
         UIKitInit:  moduleInitializationTimestamp - sdkStartDate
         ApplicationInit:  sdkStartDate - didFinishLaunchingTimestamp
         InitialFrameRender: didFinishLaunchingTimestamp - CADisplayLink.callback
         */
        BOOL isPreWarming = [self isActivePrewarmAvailable] && isActivePrewarm;
        NSNumber *appStartDuration = nil;
        long long appStartTimestamp = 0;
        NSDate *launchDate = nil;
        NSMutableDictionary *fields = [NSMutableDictionary new];
        if (isPreWarming) {
            launchDate = moduleInitializationTimestamp;
            appStartTimestamp = launchDate.ft_nanosecondTimeStamp;
            appStartDuration = [moduleInitializationTimestamp ft_nanosecondTimeIntervalToDate:endDate];
        }else{
            launchDate = [FTDateUtil processStartTimestamp];
            appStartTimestamp = launchDate.ft_nanosecondTimeStamp;
            appStartDuration = [launchDate ft_nanosecondTimeIntervalToDate:endDate];
            NSDate *processStart = launchDate;
            NSDictionary *preRuntimeInit = @{
                FT_DURATION:[processStart ft_nanosecondTimeIntervalToDate:runtimeInit],
                FT_KEY_START:@(processStart.ft_nanosecondTimeStamp - appStartTimestamp)
            };
            NSDictionary *runtimeInitDict = @{
                FT_DURATION:[runtimeInit ft_nanosecondTimeIntervalToDate:moduleInitializationTimestamp],
                FT_KEY_START:@(runtimeInit.ft_nanosecondTimeStamp - appStartTimestamp),
            };
            
            [fields setValue:preRuntimeInit forKey:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME];
            [fields setValue:runtimeInitDict forKey:FT_KEY_LAUNCH_RUNTIME_INIT_TIME];
            
        }
        // applicationDidBecomeActive after then didFinishLaunchingTimestamp,means Hybrid or
        // sdk init after -didFinishLaunching, no fileds UIKitInit/ ApplicationInit/InitialFrameRender
        if (endDate != applicationDidBecomeActive) {
            NSDate *sdkStartDate = _sdkStartDate;
            NSDictionary *uikitInit = @{
                FT_DURATION:[moduleInitializationTimestamp ft_nanosecondTimeIntervalToDate:sdkStartDate],
                FT_KEY_START:@(moduleInitializationTimestamp.ft_nanosecondTimeStamp - appStartTimestamp)
            };
            NSDictionary *appInit = @{
                FT_DURATION:[sdkStartDate ft_nanosecondTimeIntervalToDate:self.didFinishLaunchingTimestamp],
                FT_KEY_START:@(sdkStartDate.ft_nanosecondTimeStamp - appStartTimestamp),
            };
            NSDictionary *InitialFrameRender = @{
                FT_DURATION:[self.didFinishLaunchingTimestamp ft_nanosecondTimeIntervalToDate:endDate],
                FT_KEY_START:@(self.didFinishLaunchingTimestamp.ft_nanosecondTimeStamp - appStartTimestamp)
            };
            [fields setValue:uikitInit forKey:FT_KEY_LAUNCH_UIKITI_INIT_TIME];
            [fields setValue:appInit forKey:FT_KEY_LAUNCH_APP_INIT_TIME];
            [fields setValue:InitialFrameRender forKey:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME];
            
        }
        
        if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppColdStart:duration:isPreWarming:fields:)]) {
            [self.delegate ftAppColdStart:launchDate duration:appStartDuration isPreWarming:isPreWarming fields:[fields copy]];
        }
}
+ (NSDate *)sdkStartDate{
    return _sdkStartDate;
}
+ (void)setSdkStartDate:(NSDate *)sdkStartDate{
    _sdkStartDate = sdkStartDate;
}

#pragma mark - life cycle
- (void)applicationDidFinishLaunching{
    _didFinishLaunchingTimestamp = [NSDate date];
}
- (void)applicationWillEnterForeground{
    if (AppRelaunched){
        self.launchTime = FTDateUtil.date;
        self.launchTimeSystemTimestamp = FTDateUtil.systemTime;
    }
}
- (void)applicationDidBecomeActive{
    @try {
        if (AppRelaunched && _applicationDidEnterBackground) {
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
#    if FT_HOST_IOS
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

#ifdef DEBUG
// Just for testing
NSDate *FTGetApplicationDidBecomeActive(void) {
    return applicationDidBecomeActive;
}
void FTSetApplicationDidBecomeActive(NSDate *date) {
    applicationDidBecomeActive = date;
}
NSDate *FTGetModuleInitializationTimestamp(void) {
    return moduleInitializationTimestamp;
}
void FTSetModuleInitializationTimestamp(NSDate *date) {
    moduleInitializationTimestamp = date;
}
NSDate *FTGetRuntimeInit(void) {
    return runtimeInit;
}
void FTSetRuntimeInit(NSDate *date) {
    runtimeInit = date;
}
BOOL FTGetIsActivePrewarm(void) {
    return isActivePrewarm;
}
void FTSetIsActivePrewarm(BOOL active) {
    isActivePrewarm = active;
}

#endif
@end
