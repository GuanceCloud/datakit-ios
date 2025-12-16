//
//  FTUncaughtExceptionHandler.m
//  FTAutoTrack
//
//  Created by hulilei on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTCrash.h"
#import "FTSDKCompat.h"
#import "FTCrashC.h"
#import "FTLog+Private.h"
#import "FTCrashMonitor.h"
#import "FTAppLifeCycle.h"
#import <pthread.h>
#import "FTCrashMonitor_Signal.h"
#import "FTCrashBacktrace.h"
#import "FTCrashReportFilterBasic.h"
#import "FTCrashReportFilterAppleFmt.h"
#import "FTCrashReportWrapper.h"
#import "FTCrashReportStore.h"
#import "FTCrashMonitor_AppState.h"

static mach_port_t main_thread_id;
@interface FTCrash()<FTAppLifeCycleDelegate,FTBacktraceReporting>
@property (nonatomic, strong) NSHashTable *ftSDKInstances;
/** If YES, introspect memory contents during a crash.
 * Any Objective-C objects or C strings near the stack pointer or referenced by
 * cpu registers or exceptions will be recorded in the crash report, along with
 * their contents.
 *
 * Default: YES
 */
@property (nonatomic, readwrite, assign) BOOL introspectMemory;
@property (nonatomic, readwrite, retain) NSString *bundleName;

@property (nonatomic, strong) FTCrashReportStore *reportStore;
@property (nonatomic, strong) FTCrashReportWrapper *crashReportWrapper;
@end

@implementation FTCrash

+ (void)load
{   main_thread_id = (thread_t)ftcrashthread_self();
    [[self class] classDidBecomeLoaded];
}
+ (instancetype)shared {
    static FTCrash *sharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHandler = [[FTCrash alloc] init];
    });
    return sharedHandler;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        self.ftSDKInstances = [NSHashTable weakObjectsHashTable];
        self.bundleName = [self getBundleName];
        self.introspectMemory = YES;
        self.maxReportCount = 1;
        self.enableSigtermReporting = NO;
        self.reportStore = [[FTCrashReportStore alloc]init];
        self.crashReportWrapper = [[FTCrashReportWrapper alloc]init];
        [[FTAppLifeCycle sharedInstance] addAppLifecycleDelegate:self];
    }
    return self;
}

- (void)install{
    NSString *installPath = [self getDefaultInstallPath];
    if (!installPath) {
        return;
    }
    if (self.monitoring == 0) {
        return;
    }
    self.reportStore.reportCleanupPolicy = FTCrashReportCleanupPolicyNever;
    self.reportStore.sink = [[FTCrashReportFilterCombine alloc]initWithFilters:@{@"report":[FTCrashReportFilterAppleFmt new],@"rumInfo":self.crashReportWrapper}];
    
    ftcrash_install(self.bundleName.UTF8String,installPath.UTF8String,self.monitoring);
    [self sendCrashReport];
}
-(id<FTBacktraceReporting>)backtraceReporting{
    return self;
}
- (NSString *)getBundleName{
    NSString *bundleName =
    [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] ?: @"Unknown";
    return [bundleName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
}
- (NSString *)getDefaultInstallPath{
    NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([directories count] == 0) {
        FTInnerLogError(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *cachePath = [directories objectAtIndex:0];
    if ([cachePath length] == 0) {
        FTInnerLogError(@"Could not locate cache directory path.");
        return nil;
    }
    NSString *pathEnd = [@"FTCrash" stringByAppendingPathComponent:[self getBundleName]];
    return [cachePath stringByAppendingPathComponent:pathEnd];
}

-(void)setIntrospectMemory:(BOOL)introspectMemory{
    _introspectMemory = introspectMemory;
    ftcrash_setIntrospectMemory(introspectMemory);
}
- (void)addErrorDataDelegate:(id <FTErrorDataDelegate>)instance{
    if(instance == nil){
        FTInnerLogWarning(@"addErrorDataDelegate: instance is nil");
        return;
    }
    if (![self.ftSDKInstances containsObject:instance]) {
        [self.ftSDKInstances addObject:instance];
    }
}
- (void)removeErrorDataDelegate:(id <FTErrorDataDelegate>)instance{
    if(instance == nil){
        FTInnerLogWarning(@"removeErrorDataDelegate: instance is nil");
        return;
    }
    if ([self.ftSDKInstances containsObject:instance]) {
        [self.ftSDKInstances removeObject:instance];
    }
}
// ============================================================================
#pragma mark - API -
// ============================================================================

- (NSDictionary *)userInfo{
    const char *userInfoJSON = ftcrash_getUserInfoJSON();
    if (userInfoJSON != NULL && strlen(userInfoJSON) > 0) {
        NSError *error = nil;
        NSData *jsonData = [NSData dataWithBytes:userInfoJSON length:strlen(userInfoJSON)];
        NSDictionary *userInfoDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        free((void *)userInfoJSON);  // Free the allocated memory
        
        if (userInfoDict == nil) {
            FTInnerLogError(@"Error parsing JSON: %@", error.localizedDescription);
            return nil;
        }
        return userInfoDict;
    }
    return nil;
}
- (void)setUserInfo:(NSDictionary *)userInfo{
    NSError *error = nil;
    NSData *userInfoJSON = nil;
    
    if (userInfo != nil) {
        if (@available(iOS 11.0, *)) {
            userInfoJSON = [NSJSONSerialization dataWithJSONObject:userInfo options:NSJSONWritingSortedKeys error:&error];
        } else {
            userInfoJSON = [NSJSONSerialization dataWithJSONObject:userInfo options:0 error:&error];
        }
        
        if (userInfoJSON == nil) {
            FTInnerLogError(@"Could not serialize user info: %@", error.localizedDescription);
            return;
        }
    }
    
    NSString *userInfoString =
    userInfoJSON ? [[NSString alloc] initWithData:userInfoJSON encoding:NSUTF8StringEncoding] : nil;
    ftcrash_setUserInfoJSON(userInfoString.UTF8String);
}
-(void)setMaxReportCount:(int)maxReportCount{
    _maxReportCount = maxReportCount;
    ftcrash_setMaxReportCount(maxReportCount);
}

-(void)setEnableSigtermReporting:(BOOL)enableSigtermReporting{
    _enableSigtermReporting = enableSigtermReporting;
    ftcrashcm_signal_sigterm_setMonitoringEnabled(enableSigtermReporting);
}

+ (void)classDidBecomeLoaded
{
    ftcrash_notifyObjCLoad();
}

- (void)applicationDidBecomeActive{
    ftcrash_notifyAppActive(true);
}

- (void)applicationWillResignActive{
    ftcrash_notifyAppActive(false);
}
-(void)applicationDidEnterBackground{
    ftcrash_notifyAppInForeground(false);
}
-(void)applicationWillEnterForeground{
    ftcrash_notifyAppInForeground(true);
}
- (void)applicationWillTerminate{
    ftcrash_notifyAppTerminate();
}

-(NSString *)generateMainThreadBacktrace{
    return [self.crashReportWrapper generateBacktrace:main_thread_id];
}
-(NSString *)generateAllThreadsBacktrace{
    return [self.crashReportWrapper generateAllThreadsBacktrace];
}
- (double)crashedLastTimestamp{
    return ftcrashstate_currentState()->crashedLastTimestamp;
}
- (BOOL)crashedLastLaunch{
    return ftcrashstate_currentState()->crashedLastLaunch;
}
- (void)sendCrashReport{
    [self.reportStore sendAllReportsWithCompletion:^(NSArray<id<FTCrashReport>> * _Nullable filteredReports, NSError * _Nullable error) {
        NSLog(@"[FTCrash] %@",[filteredReports description]);
        
        [self.reportStore deleteAllReports];
    }];
}

@end
