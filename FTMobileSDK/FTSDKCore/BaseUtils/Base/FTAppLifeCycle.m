//
//  FTAppLifeCycle.m
//  FTMacOSSDK-framework
//
//  Created by 胡蕾蕾 on 2021/9/17.
//

#import "FTAppLifeCycle.h"
#import "FTSDKCompat.h"
@interface FTAppLifeCycle()
@property(strong, nonatomic, readonly) NSPointerArray *appLifecycleDelegates;
@property(strong, nonatomic, readonly) NSLock *delegateLock;
@end
@implementation FTAppLifeCycle
-(instancetype)init{
    self = [super init];
    if (self) {
        _appLifecycleDelegates = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
        _delegateLock = [[NSLock alloc] init];
        [self setupAppStateNotification];
    }
    return self;
}
+ (instancetype)sharedInstance{
    static FTAppLifeCycle *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}

- (void)addAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate {
    [self.delegateLock lock];
    if (![self.appLifecycleDelegates.allObjects containsObject:delegate]) {
        [self.appLifecycleDelegates addPointer:(__bridge void *)delegate];
    }
    [self.delegateLock unlock];
}
- (void)removeAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate{
    [self.delegateLock lock];
    for (NSUInteger i=0; i<self.appLifecycleDelegates.count; i++) {
        if ([self.appLifecycleDelegates pointerAtIndex:i] == (__bridge void *)delegate) {
            [self.appLifecycleDelegates removePointerAtIndex:i];
            break;
        }
    }
    [self.delegateLock unlock];
}
- (void)setupAppStateNotification{
    NSNotificationCenter *notification = [NSNotificationCenter defaultCenter];
#if FT_MAC
    [notification addObserver:self selector:@selector(applicationDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];
    
    [notification addObserver:self selector:@selector(applicationWillResignActive:) name:NSApplicationWillResignActiveNotification object:[NSApplication sharedApplication]];
    
    [notification addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];
#elif FT_IOS
    [notification addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
    [notification addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notification addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notification addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    [notification addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
#endif

}

- (void)applicationDidBecomeActive:(NSNotification *)notification{
    [self.delegateLock lock];
    for (id delegate in self.appLifecycleDelegates) {
        if ([delegate respondsToSelector:@selector(applicationDidBecomeActive)]) {
            [delegate applicationDidBecomeActive];
        }
    }
    [self.delegateLock unlock];
}
- (void)applicationWillResignActive:(NSNotification *)notification{
    [self.delegateLock lock];
    for (id delegate in self.appLifecycleDelegates) {
        if ([delegate respondsToSelector:@selector(applicationWillResignActive)]) {
            [delegate applicationWillResignActive];
        }
    }
    [self.delegateLock unlock];
}

- (void)applicationWillTerminate:(NSNotification *)notification{
    [self.delegateLock lock];
    for (id delegate in self.appLifecycleDelegates) {
        if ([delegate respondsToSelector:@selector(applicationWillTerminate)]) {
            [delegate applicationWillTerminate];
        }
    }
    [self.delegateLock unlock];
}
#if FT_IOS
- (void)applicationWillEnterForeground:(NSNotification *)notification{
    [self.delegateLock lock];
    for (id delegate in self.appLifecycleDelegates) {
        if ([delegate respondsToSelector:@selector(applicationWillEnterForeground)]) {
            [delegate applicationWillEnterForeground];
        }
    }
    [self.delegateLock unlock];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification{
    [self.delegateLock lock];
    for (id delegate in self.appLifecycleDelegates) {
        if ([delegate respondsToSelector:@selector(applicationDidEnterBackground)]) {
            [delegate applicationDidEnterBackground];
        }
    }
    [self.delegateLock unlock];
}
#endif

@end
