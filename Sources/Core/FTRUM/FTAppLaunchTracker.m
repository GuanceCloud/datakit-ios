//
//  FTAppLaunchTracker.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/2/14.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
#import "FTFirstFrameReader.h"
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
static BOOL __unused prewarmCheckStarted;
static BOOL prewarmCheckEnded;
static uint64_t __unused prewarmCheckStartNs;
static uint64_t prewarmCheckDurationNs;
static NSDate *prewarmCheckEndDate;

// Capture the source before activation can change the process task role.
static NSString *processLaunchType;
static NSDate *firstLaunchBackgroundDate;
#if FT_HAS_UIKIT
static id launchBackgroundObserver;
#endif
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
@property (nonatomic, assign) NSInteger launchPrewarmInterval;
@property (atomic, assign) BOOL stopped;
@property (nonatomic, strong) NSDate *launchTime;
@property (nonatomic, assign) uint64_t launchTimeSystemTimestamp;
@property (nonatomic, strong) NSDate *didFinishLaunchingTimestamp;
@property (nonatomic, copy, nullable) NSString *initialLaunchType;
@property (nonatomic, strong, nullable) NSDate *firstBackgroundDate;
#if FT_HAS_UIKIT
@property (atomic, strong, nullable) FTFirstFrameReader *firstFrameReader;
- (instancetype)initWithDelegate:(nullable id)delegate
                firstFrameReader:(nullable FTFirstFrameReader *)firstFrameReader;
#endif
- (instancetype)initWithLaunchDelegate:(nullable id)delegate;
- (void)handleLaunchPhaseWithoutFirstFrameReader;
@end


@implementation FTAppLaunchTracker{
    BOOL _waitingForHotLaunchReport;
    BOOL _initialLaunchReported;
    BOOL _waitingForActiveLaunchReport;
}

+ (void)prewarmCheckStart {
#if FT_HOST_IOS
    uint64_t now = FTDateUtil.continuousTime;
    if (now == 0) return;
    @synchronized (FTAppLaunchTracker.class) {
        if (!appLaunchReported && !prewarmCheckStarted) {
            prewarmCheckStarted = YES;
            prewarmCheckStartNs = now;
        }
    }
#endif
}
+ (void)prewarmCheckEnd {
#if FT_HOST_IOS
    uint64_t now = FTDateUtil.continuousTime;
    NSDate *date = FTDateUtil.date;
    if (!date || now == 0) return;
    @synchronized (FTAppLaunchTracker.class) {
        if (!appLaunchReported && prewarmCheckStarted && !prewarmCheckEnded && now > prewarmCheckStartNs) {
            prewarmCheckEnded = YES;
            prewarmCheckEndDate = date;
            prewarmCheckDurationNs = now - prewarmCheckStartNs;
        }
    }
#endif
}
#if FT_HAS_UIKIT
+ (void)stopObservingLaunchBackground {
    @synchronized (FTAppLaunchTracker.class) {
        if (launchBackgroundObserver) {
            [NSNotificationCenter.defaultCenter removeObserver:launchBackgroundObserver];
            launchBackgroundObserver = nil;
        }
    }
}

+ (void)startObservingLaunchBackground {
    @synchronized (FTAppLaunchTracker.class) {
        if (launchBackgroundObserver) return;
        launchBackgroundObserver = [NSNotificationCenter.defaultCenter
            addObserverForName:UIApplicationDidEnterBackgroundNotification
                        object:nil queue:nil usingBlock:^(NSNotification *notification) {
            // Capture on the posting thread, before any asynchronous processing.
            NSDate *time = FTDateUtil.date;
            @synchronized (FTAppLaunchTracker.class) {
                if (!launchBackgroundObserver) return;
                if (!firstLaunchBackgroundDate) firstLaunchBackgroundDate = time;
                [FTAppLaunchTracker stopObservingLaunchBackground];
            }
        }];
    }
}
#endif

+ (void)load{
    runtimeInit = [NSDate date];
    processLaunchType = FTAppLaunchType(NO);
#if FT_HAS_UIKIT
    [self startObservingLaunchBackground];
#endif

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

- (instancetype)init {
    self = [super init];
    if (self) {
        _initialLaunchType = processLaunchType;
#if FT_HOST_IOS && defined(DEBUG)
        if (launchTaskRoleOverride) _initialLaunchType = FTAppLaunchType(NO);
#endif
        @synchronized (FTAppLaunchTracker.class) {
            _initialLaunchReported = appLaunchReported;
            _firstBackgroundDate = firstLaunchBackgroundDate;
        }
    }
    return self;
}

// Testable occurrence clock; no timestamp is inferred from callback processing.
- (NSDate *)launchEventDate {
    return [NSDate date];
}

- (instancetype)initWithLaunchDelegate:(nullable id)delegate {
    self = [self init];
    if (self) {
        self.delegate = delegate;
        _didFinishLaunchingTimestamp = FTDateUtil.date;
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
#if FT_HAS_UIKIT
        // Register first, then transfer any event captured during initialization.
        // The instance now owns background tracking through the launch endpoint.
        @synchronized (FTAppLaunchTracker.class) {
            if (firstLaunchBackgroundDate &&
                (!self.firstBackgroundDate || [firstLaunchBackgroundDate compare:self.firstBackgroundDate] == NSOrderedAscending)) {
                self.firstBackgroundDate = firstLaunchBackgroundDate;
            }
            [FTAppLaunchTracker stopObservingLaunchBackground];
        }
#endif
    }
    return self;
}

- (instancetype)initWithDelegate:(nullable id)delegate {
    return [self initWithDelegate:delegate launchPrewarmInterval:0];
}
- (instancetype)initWithDelegate:(nullable id)delegate launchPrewarmInterval:(NSInteger)interval {
    self = [self initWithLaunchDelegate:delegate];
    if (self) {
        _launchPrewarmInterval = interval;
#if FT_HAS_UIKIT
        [self handleLaunchPhaseWithFirstFrameReader:[[FTFirstFrameReader alloc] init]];
#else
        [self handleLaunchPhaseWithoutFirstFrameReader];
#endif
    }
    return self;
}

#if FT_HAS_UIKIT
- (instancetype)initWithDelegate:(nullable id)delegate firstFrameReader:(nullable FTFirstFrameReader *)firstFrameReader {
    self = [self initWithLaunchDelegate:delegate];
    if (self) {
        [self handleLaunchPhaseWithFirstFrameReader:firstFrameReader];
    }
    return self;
}
#endif

#if FT_HAS_UIKIT
- (void)handleLaunchPhaseWithFirstFrameReader:(nullable FTFirstFrameReader *)firstFrameReader {
    if (_initialLaunchReported || self.stopped) return;
    if (firstFrameReader == nil) {
        [self handleLaunchPhaseWithoutFirstFrameReader];
        return;
    }
    //applicationDidBecomeActive != nil to determine if UIApplicationDidBecomeActiveNotification notification has been received before, record cold start
    if (applicationDidBecomeActive != nil) {
        [self reportAppLaunchPhaseDuration:applicationDidBecomeActive];
    } else {
        self.firstFrameReader = firstFrameReader;
        __weak typeof(self) weakSelf = self;
        [firstFrameReader startWithCallback:^(NSDate * _Nonnull date) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf.firstFrameReader stop];
            strongSelf.firstFrameReader = nil;
            [strongSelf reportAppLaunchPhaseDuration:date];
        }];
    }
}
#endif

- (void)handleLaunchPhaseWithoutFirstFrameReader {
    if (_initialLaunchReported || self.stopped) return;
    if (applicationDidBecomeActive != nil) {
        [self reportAppLaunchPhaseDuration:applicationDidBecomeActive];
    } else {
        _waitingForActiveLaunchReport = YES;
    }
}

- (void)reportAppLaunchPhaseDuration:(NSDate *)endDate{
    uint64_t manualDuration = 0;
    NSDate *manualEndDate = nil;
    @synchronized (FTAppLaunchTracker.class) {
        if (self.stopped || _initialLaunchReported) return;
        _initialLaunchReported = YES;
        _waitingForActiveLaunchReport = NO;
        if (appLaunchReported) return;
        appLaunchReported = YES;
        if (prewarmCheckEnded && [prewarmCheckEndDate compare:endDate] != NSOrderedDescending) {
            manualDuration = prewarmCheckDurationNs;
            manualEndDate = prewarmCheckEndDate;
        }
    }
    /**
     SystemInterface: processStartTimestamp - runtimeInit
     RuntimeInit:   runtimeInit -  moduleInitializationTimestamp
     UIKitInit:  moduleInitializationTimestamp - sdkStartDate
     ApplicationInit:  sdkStartDate - didFinishLaunchingTimestamp
     InitialFrameRender: didFinishLaunchingTimestamp - CADisplayLink.callback
     */
    BOOL isPreWarming = [self isActivePrewarmAvailable] && isActivePrewarm;
    NSDate *processStart = [FTDateUtil processStartTimestamp];
    NSDate *loadDate = runtimeInit;
    NSDate *preMainDate = moduleInitializationTimestamp;
    NSDate *sdkStartDate = _sdkStartDate;
    NSDate *didFinishDate = self.didFinishLaunchingTimestamp;
    NSDate *launchDate = processStart;
    BOOL validProcess = processStart.timeIntervalSince1970 > 0;

    // Always truncate a continuous prefix. Event time, duration and phase offsets
    // share this selected origin; the captured endpoint remains unchanged.
    BOOL beforeLoad = NO, afterLoad = NO;
    if (isPreWarming) {
        if (validProcess && preMainDate &&
            [preMainDate compare:processStart] != NSOrderedAscending &&
            [preMainDate compare:endDate] != NSOrderedDescending) {
            launchDate = preMainDate;
        }
    }
#if FT_HOST_IOS
    else {
        NSInteger interval = self.launchPrewarmInterval;
        if (interval > 0 && (uint64_t)interval <= INT64_MAX / 1000000ULL) {
            uint64_t threshold = (uint64_t)interval * 1000000ULL;
            // A valid manual match takes precedence over the shorter automatic prefix.
            if (validProcess && manualDuration > threshold && manualEndDate && sdkStartDate &&
                [manualEndDate compare:sdkStartDate] != NSOrderedDescending &&
                [sdkStartDate compare:processStart] != NSOrderedAscending &&
                [sdkStartDate compare:endDate] != NSOrderedDescending) {
                afterLoad = YES;
                launchDate = sdkStartDate;
            } else if (validProcess && loadDate &&
                       [loadDate compare:processStart] != NSOrderedAscending &&
                       [loadDate compare:endDate] != NSOrderedDescending &&
                       [processStart ft_nanosecondTimeIntervalToDate:loadDate].unsignedLongLongValue > threshold) {
                beforeLoad = YES;
                launchDate = loadDate;
            }
        }
    }
#endif
    NSNumber *appStartDuration = [launchDate ft_nanosecondTimeIntervalToDate:endDate];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    if (self.launchPrewarmInterval > 0 && (isPreWarming || beforeLoad || afterLoad)) {
        fields[FT_KEY_PREWARM_TYPE] = isPreWarming ? @"system" : @"custom";
    }
    BOOL anyPrewarm = isPreWarming || beforeLoad || afterLoad;
    NSString *appLaunchType = anyPrewarm ? nil : self.initialLaunchType;
    if ([appLaunchType isEqualToString:FT_APP_LAUNCH_TYPE_FOREGROUND] &&
        self.firstBackgroundDate && [self.firstBackgroundDate compare:endDate] == NSOrderedAscending) {
        appLaunchType = FT_APP_LAUNCH_TYPE_FOREGROUND_AND_BACKGROUND;
    }
    if (appLaunchType) {
        [fields setValue:appLaunchType forKey:FT_KEY_APP_LAUNCH_TYPE];
    }

    if (!isPreWarming && !beforeLoad && !afterLoad) {
        [self addLaunchPhaseFromDate:processStart
                             toDate:loadDate
                         launchDate:launchDate
                      launchEndDate:endDate
                             forKey:FT_KEY_LAUNCH_PRE_RUNTIME_INIT_TIME
                         intoFields:fields];
    }
    if (!isPreWarming && !afterLoad) {
        [self addLaunchPhaseFromDate:loadDate
                             toDate:preMainDate
                         launchDate:launchDate
                      launchEndDate:endDate
                             forKey:FT_KEY_LAUNCH_RUNTIME_INIT_TIME
                         intoFields:fields];
    }
    // A cached first-activation endpoint means tracking started after activation;
    // the last three phases are unavailable in that path.
    if (endDate != applicationDidBecomeActive) {
        if (!afterLoad) {
            [self addLaunchPhaseFromDate:preMainDate
                                 toDate:sdkStartDate
                             launchDate:launchDate
                          launchEndDate:endDate
                                 forKey:FT_KEY_LAUNCH_UIKITI_INIT_TIME
                             intoFields:fields];
        }
        [self addLaunchPhaseFromDate:sdkStartDate
                             toDate:didFinishDate
                         launchDate:launchDate
                      launchEndDate:endDate
                             forKey:FT_KEY_LAUNCH_APP_INIT_TIME
                         intoFields:fields];
        [self addLaunchPhaseFromDate:didFinishDate
                             toDate:endDate
                         launchDate:launchDate
                      launchEndDate:endDate
                             forKey:FT_KEY_LAUNCH_FIRST_FRAME_RENDER_TIME
                         intoFields:fields];
    }

    if ([self.delegate respondsToSelector:@selector(ftAppColdStart:duration:isPreWarming:fields:endDate:)]) {
        [self.delegate ftAppColdStart:launchDate duration:appStartDuration isPreWarming:anyPrewarm fields:[fields copy] endDate:endDate];
    } else if ([self.delegate respondsToSelector:@selector(ftAppColdStart:duration:isPreWarming:fields:)]) {
        [self.delegate ftAppColdStart:launchDate duration:appStartDuration isPreWarming:anyPrewarm fields:[fields copy]];
    }
}
- (nullable NSDictionary *)launchPhaseFromDate:(nullable NSDate *)fromDate
                                      toDate:(nullable NSDate *)toDate
                                  launchDate:(NSDate *)launchDate{
    if (fromDate == nil || toDate == nil) {
        return nil;
    }
    if ([toDate compare:fromDate] == NSOrderedAscending) {
        return nil;
    }
    if ([fromDate compare:launchDate] == NSOrderedAscending) return nil;
    long long start = [launchDate ft_nanosecondTimeIntervalToDate:fromDate].longLongValue;
    long long end = [launchDate ft_nanosecondTimeIntervalToDate:toDate].longLongValue;
    if (start < 0) {
        return nil;
    }
    return @{
        FT_DURATION:@(end - start),
        FT_KEY_START:@(start)
    };
}
- (void)addLaunchPhaseFromDate:(nullable NSDate *)fromDate
                      toDate:(nullable NSDate *)toDate
                  launchDate:(NSDate *)launchDate
               launchEndDate:(NSDate *)endDate
                      forKey:(NSString *)key
                  intoFields:(NSMutableDictionary *)fields{
    if (toDate && [toDate compare:endDate] == NSOrderedDescending) return;
    NSDictionary *phase = [self launchPhaseFromDate:fromDate toDate:toDate launchDate:launchDate];
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
    if (self.stopped) return;
    _didFinishLaunchingTimestamp = [NSDate date];
}
- (void)applicationWillEnterForeground{
    if (self.stopped) return;
    if (appLaunchReported){
        self.launchTime = FTDateUtil.date;
        self.launchTimeSystemTimestamp = FTDateUtil.systemTime;
        _waitingForHotLaunchReport = YES;
    }
}
- (void)applicationDidBecomeActive{
    if (self.stopped) return;
    @try {
        if (appLaunchReported && _waitingForHotLaunchReport) {
            NSNumber *duration = @(FTDateUtil.systemTime - self.launchTimeSystemTimestamp);
            _waitingForHotLaunchReport = NO;
            if (self.delegate&&[self.delegate respondsToSelector:@selector(ftAppHotStart:duration:)]) {
                [self.delegate ftAppHotStart:self.launchTime duration:duration];
            }
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
    if (self.stopped) return;
    NSDate *time = [self launchEventDate];
    if (!_initialLaunchReported && time &&
        (!self.firstBackgroundDate || [time compare:self.firstBackgroundDate] == NSOrderedAscending)) {
        self.firstBackgroundDate = time;
    }
    _waitingForHotLaunchReport = NO;
}
- (BOOL)isActivePrewarmAvailable{
#    if FT_HOST_IOS
    // User data shows that iOS 14 app launches also have prewarming, which contradicts Apple's documentation that support starts from iOS 15.
    return YES;
#    else
    return NO;
#    endif
}

- (void)shutDown {
    @synchronized (FTAppLaunchTracker.class) {
        self.stopped = YES;
    }
#if FT_HAS_UIKIT
    [self.firstFrameReader stop];
    self.firstFrameReader = nil;
#endif
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}
-(void)dealloc{
#if FT_HAS_UIKIT
    [_firstFrameReader stop];
#endif
    [[FTAppLifeCycle sharedInstance] removeAppLifecycleDelegate:self];
}

#ifdef DEBUG
// Just for testing
+ (NSDictionary *)resetPrewarmCheckForTesting {
    @synchronized (FTAppLaunchTracker.class) {
        NSDictionary *previous = @{@"reported": @(appLaunchReported), @"started": @(prewarmCheckStarted),
            @"ended": @(prewarmCheckEnded), @"start": @(prewarmCheckStartNs),
            @"duration": @(prewarmCheckDurationNs), @"endDate": prewarmCheckEndDate ?: NSNull.null};
        prewarmCheckStarted = NO; prewarmCheckEnded = NO;
        prewarmCheckStartNs = 0; prewarmCheckDurationNs = 0; prewarmCheckEndDate = nil; appLaunchReported = NO;
        return previous;
    }
}
+ (void)restorePrewarmCheckForTesting:(NSDictionary *)previous {
    @synchronized (FTAppLaunchTracker.class) {
        appLaunchReported = [previous[@"reported"] boolValue];
        prewarmCheckStarted = [previous[@"started"] boolValue];
        prewarmCheckEnded = [previous[@"ended"] boolValue];
        prewarmCheckStartNs = [previous[@"start"] unsignedLongLongValue];
        prewarmCheckDurationNs = [previous[@"duration"] unsignedLongLongValue];
        prewarmCheckEndDate = previous[@"endDate"] == NSNull.null ? nil : previous[@"endDate"];
    }
}
NSDate *FTGetFirstLaunchBackgroundDate(void) {
    @synchronized (FTAppLaunchTracker.class) { return firstLaunchBackgroundDate; }
}
void FTSetFirstLaunchBackgroundDate(NSDate *date) {
    @synchronized (FTAppLaunchTracker.class) { firstLaunchBackgroundDate = date; }
}
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
