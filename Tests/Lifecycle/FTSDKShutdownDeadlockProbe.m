// Copyright 2026 TRUEWATCH TECHNOLOGY INC PTE. LTD.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Cross-queue lifecycle regression App, also runnable against the historical deadlock.
// Module-only cases live in FTResourceLifecycleTest; keep process isolation here
// because a regressed collector can block shutdown while its provider is running.
// The external runner isolates hangs and checks explicit completion/count markers.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <pthread.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import "FTSDKAgent.h"
#import "FTSDKConfig.h"
#import "FTRumConfig.h"
#import "FTURLSessionInterceptor.h"
#import "FTURLSessionInstrumentation.h"
#import "FTRUMManager.h"
#import "FTURLSessionDelegate+Private.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTDURLSessionDelegate.h"
#import "FTTraceContext.h"
#import "FTPresetProperty.h"
#import "FTRUMPropertySnapshot.h"

extern void *FTInterceptorQueueIdentityKey;

static NSString *gMode;
static NSString *gRunID;
static int gMarkerFD = -1;
static pthread_mutex_t gMarkerLock = PTHREAD_MUTEX_INITIALIZER;
static NSUInteger gSequence;
static dispatch_semaphore_t gProviderGate;
static FTURLSessionInterceptor *gInterceptor;
static IMP gOriginalShutdown;
static NSURLSession *gSession;
static NSURLSessionDataTask *gTask;
static atomic_int gProviderEntries;
static atomic_int gProviderReturns;
static atomic_int gCompletionReturns;
static atomic_int gShutdownCalls;
static atomic_int gShutdownReturns;
static atomic_bool gGateReleased;
static atomic_bool gFinished;

static atomic_int gLateTraceCalls;
static atomic_int gResourceAdds;
static id gRestartReceiver;
static atomic_int gNewResourceAdds;
static atomic_int gNewProviderEntries;
static atomic_int gNewCompletions;
static atomic_bool gRestartVerified;
static IMP gOriginalAdd;
static atomic_bool gSettlementCheckScheduled;
static atomic_bool gSettlementChecked;
static void LCObservedAdd(id receiver, SEL selector, NSString *key, id metrics, id content, NSString *span, NSString *trace) {
    atomic_fetch_add(&gResourceAdds, 1);
    if (receiver == gRestartReceiver) atomic_fetch_add(&gNewResourceAdds, 1);
    ((void (*)(id, SEL, id, id, id, id, id))gOriginalAdd)(receiver, selector, key, metrics, content, span, trace);
}
static FTSDKConfig *gBase;
static FTRumConfig *gRum;
static FTURLSessionInterceptor *gNewInterceptor;
static BOOL LCIsMode(NSString *mode) { return [gMode isEqualToString:mode]; }

static void LCMark(NSString *event, NSDictionary *details) {
    pthread_mutex_lock(&gMarkerLock);
    uint64_t threadID = 0;
    pthread_threadid_np(NULL, &threadID);
    NSMutableDictionary *record = [@{
        @"event": event, @"sequence": @(++gSequence), @"mode": gMode,
        @"run_id": gRunID, @"pid": @(getpid()), @"thread_id": @(threadID),
        @"main": @(NSThread.isMainThread),
        @"queue": @(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)),
        @"uptime_seconds": @(NSProcessInfo.processInfo.systemUptime)
    } mutableCopy];
    if (details) [record addEntriesFromDictionary:details];
    NSData *json = [NSJSONSerialization dataWithJSONObject:record options:0 error:nil];
    NSMutableData *line = [json mutableCopy];
    [line appendBytes:"\n" length:1];
    const char *bytes = line.bytes;
    NSUInteger remaining = line.length;
    while (remaining) {
        ssize_t count = write(gMarkerFD, bytes, remaining);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) _exit(3);
        remaining -= (NSUInteger)count;
        bytes += count;
    }
    pthread_mutex_unlock(&gMarkerLock);
}

static void LCRequire(BOOL condition, NSString *reason) {
    if (!condition) {
        LCMark(@"probe-failed", @{@"reason": reason});
        _exit(2);
    }
}

// Exercise both manual forwarding and the automatic delegate's late callbacks.
static void LCLateCallbacks(void) {
    FTURLSessionDelegate *manual = [FTURLSessionDelegate new];
    FTDURLSessionDelegate *automatic = [FTDURLSessionDelegate new];
    NSData *data = [@"late" dataUsingEncoding:NSUTF8StringEncoding];
    [manual URLSession:gSession dataTask:gTask didReceiveData:data];
    [manual taskReceivedCompleteData:gTask data:data];
    [manual URLSession:gSession task:gTask didFinishCollectingMetrics:nil];
    [manual URLSession:gSession task:gTask didCompleteWithError:nil];
    [manual URLSession:gSession task:gTask didCompleteWithError:nil];
    [manual taskCompleted:gTask error:nil endTime:1];
    [automatic URLSession:gSession dataTask:gTask didReceiveData:data];
    [automatic URLSession:gSession task:gTask didFinishCollectingMetrics:nil];
    [automatic URLSession:gSession task:gTask didCompleteWithError:nil];
    [automatic URLSession:gSession task:gTask didCompleteWithError:nil];
}

static void LCStartNewRequest(void);
static void LCTryFinish(void) {
    if (LCIsMode(@"restart") && atomic_load(&gSettlementChecked) && !atomic_load(&gRestartVerified)) return;
    int expectedProviders = 1;
    int expectedShutdown = 1;
    if (atomic_load(&gProviderReturns) != expectedProviders ||
        atomic_load(&gCompletionReturns) != 1 ||
        atomic_load(&gShutdownReturns) != expectedShutdown) return;
    if (!atomic_exchange(&gSettlementCheckScheduled, true)) {
        dispatch_queue_t queue = [gInterceptor valueForKey:@"queue"];
        dispatch_async(queue, ^{
            if (LCIsMode(@"restart")) {
                LCRequire([FTURLSessionInterceptor shared] == gNewInterceptor, @"old lifecycle detached new instance");
                LCRequire([gNewInterceptor valueForKey:@"resourcePropertyProvider"] != nil, @"old lifecycle cleared new provider");
                LCRequire([gNewInterceptor valueForKey:@"rumResourceHandler"] != nil, @"old lifecycle cleared new receiver");
                NSDictionary *context = [FTPresetProperty sharedInstance].rumPropertySnapshot.tags;
                LCRequire([context[@"lc001_lifecycle"] isEqual:@"new"], @"restart lost new global context");
                LCRequire([context[@"lc001_context"] isEqual:@"callback"], @"explicit application Context call did not target current SDK");
            }
            int expectedAdds = 0;
            LCRequire(atomic_load(&gResourceAdds) == expectedAdds, @"Resource settlement count mismatch");
            LCMark(@"resource-settlement-verified", @{@"adds": @(expectedAdds)});
            atomic_store(&gSettlementChecked, true);
            if (LCIsMode(@"restart")) LCStartNewRequest();
            LCTryFinish();
        });
        return;
    }
    if (!atomic_load(&gSettlementChecked)) return;
    if (atomic_exchange(&gFinished, true)) return;
    LCRequire(atomic_load(&gProviderEntries) == expectedProviders, @"provider count mismatch");
    LCRequire(atomic_load(&gShutdownCalls) == expectedShutdown, @"shutdown count mismatch");
    if (LCIsMode(@"restart")) {
        LCRequire(atomic_load(&gNewProviderEntries) == 1 && atomic_load(&gNewCompletions) == 1, @"new lifecycle callback count mismatch");
        LCRequire(atomic_load(&gNewResourceAdds) == 1 && atomic_load(&gResourceAdds) == 1, @"Resource crossed lifecycle receiver");
    }
    LCMark(@"case-complete", @{
        @"provider_entries": @(atomic_load(&gProviderEntries)),
        @"provider_returns": @(atomic_load(&gProviderReturns)),
        @"application_completions": @(atomic_load(&gCompletionReturns)),
        @"shutdown_returns": @(atomic_load(&gShutdownReturns))
    });
    // Remain alive so the external host can collect evidence and stop this PID.
}

__attribute__((noinline)) static void LCShutdown(void) {
    LCRequire(atomic_fetch_add(&gShutdownCalls, 1) == 0, @"duplicate shutdown");
    LCMark(@"sdk-shutdown-called", nil);
    [FTSDKAgent shutDown];
    [FTSDKAgent shutDown];
    atomic_fetch_add(&gShutdownReturns, 1);
    LCMark(@"sdk-shutdown-returned", nil);
    LCTryFinish();
}

__attribute__((noinline)) static void LCObservedInterceptorShutdown(id object, SEL selector) {
    LCRequire(object == gInterceptor, @"shutdown reached another interceptor");
    BOOL onInterceptor = dispatch_get_specific(FTInterceptorQueueIdentityKey) != NULL;
    LCRequire(!onInterceptor, @"cross-queue probe shutdown unexpectedly ran on the interceptor queue");
    LCMark(@"shutdown-reached-interceptor", @{
        @"on_interceptor": @(onInterceptor),
        @"automatic_rum_enabled": @([FTURLSessionInstrumentation sharedInstance].shouldRUMInterceptor)
    });
    if (LCIsMode(@"primary") || LCIsMode(@"no-reentry")) {
        // Public SDK shutdown has already acquired its monitor. This wrapper
        // releases a test gate and adds no wait/lock to the production cycle.
        atomic_store(&gGateReleased, true);
        dispatch_semaphore_signal(gProviderGate);
    }
    ((void (*)(id, SEL))gOriginalShutdown)(object, selector);
    LCMark(@"interceptor-shutdown-returned", nil);
}

__attribute__((noinline)) static NSDictionary *LCResourceProvider(NSURLRequest *request) {
    LCRequire([request.URL.host isEqualToString:@"lc001.test"], @"unexpected provider request");
    if ([request.URL.path isEqualToString:@"/new-resource"]) {
        LCRequire(atomic_fetch_add(&gNewProviderEntries, 1) == 0, @"duplicate new provider");
        LCMark(@"new-provider-entered", nil);
        dispatch_async([gNewInterceptor valueForKey:@"queue"], ^{
            LCRequire(atomic_load(&gResourceAdds) == 1, @"new Resource settlement count mismatch");
            LCRequire(atomic_load(&gNewResourceAdds) == 1, @"new Resource used wrong receiver");
            LCRequire(atomic_load(&gNewCompletions) == 1, @"new completion count mismatch");
            atomic_store(&gRestartVerified, true);
            LCMark(@"new-lifecycle-verified", @{@"resource_adds": @1, @"old_resource_adds": @0});
            LCTryFinish();
        });
        return @{@"lc001_provider": @"new-lifecycle"};
    }
    LCRequire(!NSThread.isMainThread, @"provider unexpectedly on main");
    LCRequire(dispatch_get_specific(FTInterceptorQueueIdentityKey) != NULL, @"provider not on real interceptor queue");
    LCRequire(atomic_fetch_add(&gProviderEntries, 1) == 0, @"duplicate provider entry");
    LCMark(@"provider-entered", @{@"url": request.URL.absoluteString});
    if (LCIsMode(@"primary") || LCIsMode(@"no-reentry") || LCIsMode(@"blocked-provider") || LCIsMode(@"restart")) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LCShutdown();
            if (LCIsMode(@"restart")) {
                gBase.globalContext = @{@"lc001_lifecycle": @"new"};
                [FTSDKAgent startWithConfigOptions:gBase];
                [[FTSDKAgent sharedInstance] startRumWithConfigOptions:gRum];
                gNewInterceptor = [FTURLSessionInterceptor shared];
                gRestartReceiver = [gNewInterceptor valueForKey:@"rumResourceHandler"];
                LCRequire(gNewInterceptor != gInterceptor, @"restart reused old interceptor");
                // A late repeated stop on an old adapter must not detach the new one.
                ((void (*)(id, SEL))gOriginalShutdown)(gInterceptor, NSSelectorFromString(@"shutDown"));
                LCRequire([FTURLSessionInterceptor shared] == gNewInterceptor, @"old stop cleared new interceptor");
                LCLateCallbacks();
                // Resuming an admitted old task must not acquire the new lifecycle.
                FTURLSessionDelegate *manual = [FTURLSessionDelegate new];
                manual.traceInterceptor = ^FTTraceContext *(NSURLRequest *request) {
                    atomic_fetch_add(&gLateTraceCalls, 1);
                    return nil;
                };
                [(id<FTURLSessionInterceptorProtocol>)manual traceInterceptTask:gTask];
                [manual interceptTask:gTask];
                LCRequire(atomic_load(&gLateTraceCalls) == 0, @"old task invoked new lifecycle Trace callback");
                LCMark(@"restart-isolated", nil);
            }
            if (LCIsMode(@"blocked-provider") || LCIsMode(@"restart")) {
                LCRequire(atomic_load(&gProviderReturns) == 0, @"provider returned before shutdown");
                atomic_store(&gGateReleased, true);
                dispatch_semaphore_signal(gProviderGate);
            }
        });
        dispatch_semaphore_wait(gProviderGate, DISPATCH_TIME_FOREVER);
        LCRequire(atomic_load(&gGateReleased), @"provider gate not released");
        LCMark(@"provider-gate-released", nil);
    }
    if (!LCIsMode(@"no-reentry")) {
        LCMark(@"context-call-entered", nil);
        [FTSDKAgent appendGlobalContext:@{@"lc001_context": @"callback"}];
        LCMark(@"context-call-returned", nil);
    }
    atomic_fetch_add(&gProviderReturns, 1);
    LCMark(@"provider-returned", nil);
    LCTryFinish();
    return @{@"lc001_provider": @"visited"};
}

@interface FTLC001URLProtocol : NSURLProtocol
@end
@implementation FTLC001URLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return [request.URL.host isEqualToString:@"lc001.test"];
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    LCMark(@"protocol-started", nil);
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
        statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:[@"{\"probe\":\"LC-001\"}" dataUsingEncoding:NSUTF8StringEncoding]];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end

static void LCStart(void) {
    LCRequire(NSThread.isMainThread, @"startup must be main");
    gProviderGate = dispatch_semaphore_create(0);
    FTSDKConfig *base = [[FTSDKConfig alloc] initWithDatakitUrl:@"http://127.0.0.1:1"];
    base.globalContext = @{@"lc001_lifecycle": @"old"};
    base.autoSync = NO;
    base.enableDataFilter = NO;
    base.remoteConfiguration = NO;
    base.enableSDKDebugLog = NO;
    Method addMethod = class_getInstanceMethod(FTRUMManager.class, @selector(addResourceWithKey:metrics:content:spanID:traceID:));
    gOriginalAdd = method_setImplementation(addMethod, (IMP)LCObservedAdd);
    gBase = base;
    [FTSDKAgent startWithConfigOptions:base];
    FTRumConfig *rum = [[FTRumConfig alloc] initWithAppid:@"lc001-isolated-audit"];
    rum.enableTraceUserResource = YES;
    rum.enableTraceUserView = NO;
    rum.enableTraceUserAction = NO;
    rum.enableTrackAppCrash = NO;
    rum.enableTrackAppANR = NO;
    rum.enableTrackAppFreeze = NO;
    rum.deviceMetricsMonitorType = 0;
    rum.enableTraceURLConnectionResource = NO;
    rum.enableTraceWebView = NO;
    rum.resourcePropertyProvider = ^NSDictionary *(NSURLRequest *request, NSURLResponse *response, NSData *data, NSError *error) {
        return LCResourceProvider(request);
    };
    gRum = rum;
    [[FTSDKAgent sharedInstance] startRumWithConfigOptions:rum];
    gInterceptor = [FTURLSessionInterceptor shared];
    Method stopMethod = class_getInstanceMethod(FTURLSessionInterceptor.class, NSSelectorFromString(@"shutDown"));
    LCRequire(stopMethod != NULL, @"missing interceptor shutdown");
    gOriginalShutdown = method_setImplementation(stopMethod, (IMP)LCObservedInterceptorShutdown);
    LCMark(@"sdk-started", @{
        @"automatic_rum_enabled": @([FTURLSessionInstrumentation sharedInstance].shouldRUMInterceptor),
        @"task_hook_class_exists": @(NSClassFromString(@"__NSCFLocalSessionTask") != Nil)
    });
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.protocolClasses = @[FTLC001URLProtocol.class];
    gSession = [NSURLSession sessionWithConfiguration:config];
    gTask = [gSession dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://lc001.test/resource"]]
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        LCRequire(!error && [(NSHTTPURLResponse *)response statusCode] == 200, @"request did not succeed");
        LCRequire(atomic_fetch_add(&gCompletionReturns, 1) == 0, @"duplicate application completion");
        LCMark(@"application-completion-returning", @{@"body_bytes": @(data.length)});
        LCTryFinish();
    }];
    LCMark(@"task-created", @{@"task_class": NSStringFromClass(gTask.class), @"session_delegate": NSStringFromClass(gSession.delegate.class)});
    [gTask resume];
}

static void LCStartNewRequest(void) {
    NSURLSessionDataTask *task = [gSession dataTaskWithURL:[NSURL URLWithString:@"https://lc001.test/new-resource"]
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            LCRequire(!error && [(NSHTTPURLResponse *)response statusCode] == 200, @"new request failed");
            LCRequire(atomic_fetch_add(&gNewCompletions, 1) == 0, @"duplicate new completion");
            LCMark(@"new-application-completion", nil);
        }];
    [task resume];
}

@interface FTLC001SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation FTLC001SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [UIViewController new];
    self.window.rootViewController.view.backgroundColor = UIColor.whiteColor;
    [self.window makeKeyAndVisible];
}
- (void)sceneDidBecomeActive:(UIScene *)scene {
    static BOOL started = NO;
    if (started) return;
    started = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ LCStart(); });
}
@end

@interface FTLC001AppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation FTLC001AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options { return YES; }
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;
        NSUInteger caseIndex = [args indexOfObject:@"--case"];
        NSUInteger runIndex = [args indexOfObject:@"--run-id"];
        if (caseIndex == NSNotFound || caseIndex + 1 >= args.count || runIndex == NSNotFound || runIndex + 1 >= args.count) return 2;
        gMode = args[caseIndex + 1];
        gRunID = args[runIndex + 1];
        NSSet *modes = [NSSet setWithArray:@[@"primary", @"no-reentry", @"blocked-provider", @"restart"]];
        if (![modes containsObject:gMode] || [gRunID containsString:@"/"] || [gRunID isEqualToString:@".."] || !gRunID.length) return 2;
        NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *directory = [[documents stringByAppendingPathComponent:@"LC001"] stringByAppendingPathComponent:gRunID];
        if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]) return 3;
        gMarkerFD = open([[directory stringByAppendingPathComponent:@"markers.jsonl"] fileSystemRepresentation], O_WRONLY | O_CREAT | O_EXCL | O_APPEND, 0600);
        if (gMarkerFD < 0) return 3;
        LCMark(@"process-started", @{@"os": NSProcessInfo.processInfo.operatingSystemVersionString});
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(FTLC001AppDelegate.class));
    }
}
