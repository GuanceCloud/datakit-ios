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
#import "FTInnerLog.h"
#import "NSDate+FTUtil.h"
#import "FTDateUtil.h"
#import "FTDisplayRateMonitor.h"
#import "FTConstants.h"
#if FT_HOST_IOS
#import <mach/mach.h>
#import <mach/task_policy.h>
#endif

static NSDate *_sdkStartDate = nil;
static NSDate *applicationDidBecomeActive;
static NSDate *moduleInitializationTimestamp;
static NSDate *runtimeInit = nil;
static BOOL isActivePrewarm = NO;
static BOOL appLaunchReported = NO;
#if FT_HOST_IOS && defined(DEBUG)
static NSNumber *launchTaskRoleOverride = nil;
#endif

static NSString *FTAppLaunchType(BOOL isPreWarming) {
    if (isPreWarming) {
        return nil;
    }
#if FT_HOST_IOS
    task_role_t role = TASK_UNSPECIFIED;
#if defined(DEBUG)
    if (launchTaskRoleOverride) {
        role = (task_role_t)launchTaskRoleOverride.integerValue;
    } else
#endif
    {
        task_category_policy_data_t policy;
        mach_msg_type_number_t count = TASK_CATEGORY_POLICY_COUNT;
        boolean_t getDefault = false;
        kern_return_t result = task_policy_get(mach_task_self(),
                                               TASK_CATEGORY_POLICY,
                                               (task_policy_t)&policy,
                                               &count,
                                               &getDefault);
        if (result != KERN_SUCCESS) {
            return FT_APP_LAUNCH_TYPE_BACKGROUND;
        }
        role = policy.role;
    }
    return role == TASK_FOREGROUND_APPLICATION ? FT_APP_LAUNCH_TYPE_FOREGROUND : FT_APP_LAUNCH_TYPE_BACKGROUND;
#else
    return nil;
#endif
}

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
    BOOL _initialLaunchReported;
    BOOL _waitingForActiveLaunchReport;
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
- (instancetype)initWithDelegate:(nullable id)delegate displayMonitor:(nullable FTDisplayRateMonitor *)displayMonitor{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        _didFinishLaunchingTimestamp = FTDateUtil.date;
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];

        [self handleLaunchPhaseWithDisplayMonitor:displayMonitor];
    }
    return self;
}
- (void)handleLaunchPhaseWithDisplayMonitor:(nullable FTDisplayRateMonitor *)displayMonitor {
    //applicationDidBecomeActive != nil to determine if UIApplicationDidBecomeActiveNotification notification has been received before, record cold start
    if (applicationDidBecomeActive != nil) {
        [self reportAppLaunchPhaseDuration:applicationDidBecomeActive];
    } else if (displayMonitor != nil) {
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
        } else {
            [self reportAppLaunchPhaseDuration:firstFrame];
        }
    } else {
        _waitingForActiveLaunchReport = YES;
    }
}
- (void)reportAppLaunchPhaseDuration:(NSDate *)endDate{
    if (_initialLaunchReported) {
        return;
    }
    _initialLaunchReported = YES;
    appLaunchReported = YES;
    /**
     SystemInterface: processStartTimestamp - runtimeInit
     RuntimeInit:   runtimeInit -  moduleInitializationTimestamp
     UIKitInit:  moduleInitializationTimestamp - sdkStartDate
     ApplicationInit:  sdkStartDate - didFinishLaunchingTimestamp
     InitialFrameRender: didFinishLaunchingTimestamp - CADisplayLink.callback
     */
    BOOL isPreWarming = [self isActivePrewarmAvailable] && isActivePrewarm;
    NSDate *processStart = [FTDateUtil processStartTimestamp];
    NSDate *launchDate = processStart;
    long long appStartTimestamp = launchDate.ft_nanosecondTimeStamp;
    NSNumber *appStartDuration = [launchDate ft_nanosecondTimeIntervalToDate:endDate];

    NSMutableDictionary *fields = [NSMutableDictionary new];
    NSString *appLaunchType = FTAppLaunchType(isPreWarming);
    if (appLaunchType) {
        [fields setValue:appLaunchType forKey:FT_KEY_APP_LAUNCH_TYPE];
    }

    if (!isPreWarming) {
        [self addLaunchPhaseFromDate:processStart
                               toDate:runtimeInit
                    appStartTimestamp:appStartTimestamp
                               forKey:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME
                           intoFields:fields];
        [self addLaunchPhaseFromDate:runtimeInit
                               toDate:moduleInitializationTimestamp
                    appStartTimestamp:appStartTimestamp
                               forKey:FT_KEY_LAUNCH_RUNTIME_INIT_TIME
                           intoFields:fields];

    }
    // applicationDidBecomeActive after then didFinishLaunchingTimestamp,means Hybrid or
    // sdk init after -didFinishLaunching, no fileds UIKitInit/ ApplicationInit/InitialFrameRender
    if (endDate != applicationDidBecomeActive) {
        NSDate *sdkStartDate = _sdkStartDate;
        [self addLaunchPhaseFromDate:moduleInitializationTimestamp
                               toDate:sdkStartDate
                    appStartTimestamp:appStartTimestamp
                               forKey:FT_KEY_LAUNCH_UIKITI_INIT_TIME
                           intoFields:fields];
        [self addLaunchPhaseFromDate:sdkStartDate
                               toDate:self.didFinishLaunchingTimestamp
                    appStartTimestamp:appStartTimestamp
                               forKey:FT_KEY_LAUNCH_APP_INIT_TIME
                           intoFields:fields];
        [self addLaunchPhaseFromDate:self.didFinishLaunchingTimestamp
                               toDate:endDate
                    appStartTimestamp:appStartTimestamp
                               forKey:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME
                           intoFields:fields];

    }

    if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppColdStart:duration:isPreWarming:fields:)]) {
        [self.delegate ftAppColdStart:launchDate duration:appStartDuration isPreWarming:isPreWarming fields:[fields copy]];
    }
}
- (nullable NSDictionary *)launchPhaseFromDate:(nullable NSDate *)fromDate
                                        toDate:(nullable NSDate *)toDate
                             appStartTimestamp:(long long)appStartTimestamp{
    if (fromDate == nil || toDate == nil) {
        return nil;
    }
    if ([toDate compare:fromDate] == NSOrderedAscending) {
        return nil;
    }
    long long start = fromDate.ft_nanosecondTimeStamp - appStartTimestamp;
    if (start < 0) {
        return nil;
    }
    return @{
        FT_DURATION:[fromDate ft_nanosecondTimeIntervalToDate:toDate],
        FT_KEY_START:@(start)
    };
}
- (void)addLaunchPhaseFromDate:(nullable NSDate *)fromDate
                         toDate:(nullable NSDate *)toDate
              appStartTimestamp:(long long)appStartTimestamp
                         forKey:(NSString *)key
                     intoFields:(NSMutableDictionary *)fields{
    NSDictionary *phase = [self launchPhaseFromDate:fromDate toDate:toDate appStartTimestamp:appStartTimestamp];
    if (phase) {
        [fields setValue:phase forKey:key];
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
    if (appLaunchReported){
        self.launchTime = FTDateUtil.date;
        self.launchTimeSystemTimestamp = FTDateUtil.systemTime;
    }
}
- (void)applicationDidBecomeActive{
    @try {
        if (appLaunchReported && _applicationDidEnterBackground) {
            NSNumber *duration = @(FTDateUtil.systemTime - self.launchTimeSystemTimestamp);
            if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppHotStart:duration:)]) {
                [self.delegate ftAppHotStart:self.launchTime duration:duration];
            }
            _applicationDidEnterBackground = NO;
        }else if (_waitingForActiveLaunchReport) {
            NSDate *activeDate = applicationDidBecomeActive ?: NSDate.date;
            applicationDidBecomeActive = activeDate;
            _waitingForActiveLaunchReport = NO;
            [self reportAppLaunchPhaseDuration:activeDate];
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
#if FT_HOST_IOS
void FTSetLaunchTaskRole(NSInteger role) {
    launchTaskRoleOverride = @(role);
}
void FTClearLaunchTaskRole(void) {
    launchTaskRoleOverride = nil;
}
#endif

#endif
@end
