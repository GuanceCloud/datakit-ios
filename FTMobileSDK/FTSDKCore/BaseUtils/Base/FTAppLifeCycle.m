//
//  FTAppLifeCycle.m
//  FTMacOSSDK-framework
//
//  Created by hulilei on 2021/9/17.
//

#import "FTAppLifeCycle.h"
#import "FTSDKCompat.h"
#if FT_HOST_MAC
    #import <AppKit/AppKit.h>
#else
    #if FT_HAS_UIKIT
        #import <UIKit/UIKit.h>
    #endif
#endif
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
    if (!delegate) return;
        [self.delegateLock lock];
        @try {
            if (![self.appLifecycleDelegates.allObjects containsObject:delegate]) {
                [self.appLifecycleDelegates addPointer:(__bridge void *)delegate];
            }
        } @finally {
            [self.delegateLock unlock]; 
        }
}
- (void)removeAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate{
    if (!delegate) return;
       [self.delegateLock lock];
       @try {
           NSUInteger indexToRemove = NSNotFound;
           for (NSUInteger i = 0; i < self.appLifecycleDelegates.count; i++) {
               void *pointer = [self.appLifecycleDelegates pointerAtIndex:i];
               if (pointer == (__bridge void *)delegate) {
                   indexToRemove = i;
                   break;
               }
           }
           if (indexToRemove != NSNotFound) {
               [self.appLifecycleDelegates removePointerAtIndex:indexToRemove];
           }
       } @finally {
           [self.delegateLock unlock];
       }
}
- (void)setupAppStateNotification{
    NSNotificationCenter *notification = [NSNotificationCenter defaultCenter];
#if FT_HOST_MAC
    [notification addObserver:self selector:@selector(applicationDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];
    
    [notification addObserver:self selector:@selector(applicationWillResignActive:) name:NSApplicationWillResignActiveNotification object:[NSApplication sharedApplication]];
    
    [notification addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];
#elif FT_HAS_UIKIT
    [notification addObserver:self
                           selector:@selector(applicationDidFinishLaunching:)
                               name:UIApplicationDidFinishLaunchingNotification
                             object:nil];
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
- (void)enumerateAppLifecycleDelegatesWithBlock:(void (^)(id<FTAppLifeCycleDelegate> delegate))block{
    if (!block) return;
    NSArray *delegates = nil;
    [self.delegateLock lock];
    @try {
        delegates = self.appLifecycleDelegates.allObjects;
    } @finally {
        [self.delegateLock unlock];
    }
    for (id<FTAppLifeCycleDelegate> delegate in delegates) {
        block(delegate);
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification{
    [self enumerateAppLifecycleDelegatesWithBlock:^(id<FTAppLifeCycleDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(applicationDidFinishLaunching)]) {
            [delegate applicationDidFinishLaunching];
        }
    }];
}
- (void)applicationDidBecomeActive:(NSNotification *)notification{
    [self enumerateAppLifecycleDelegatesWithBlock:^(id<FTAppLifeCycleDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(applicationDidBecomeActive)]) {
            [delegate applicationDidBecomeActive];
        }
    }];
}
- (void)applicationWillResignActive:(NSNotification *)notification{
    [self enumerateAppLifecycleDelegatesWithBlock:^(id<FTAppLifeCycleDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(applicationWillResignActive)]) {
            [delegate applicationWillResignActive];
        }
    }];
}

- (void)applicationWillTerminate:(NSNotification *)notification{
    [self enumerateAppLifecycleDelegatesWithBlock:^(id<FTAppLifeCycleDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(applicationWillTerminate)]) {
            [delegate applicationWillTerminate];
        }
    }];
}
#if FT_HAS_UIKIT
- (void)applicationWillEnterForeground:(NSNotification *)notification{
    [self enumerateAppLifecycleDelegatesWithBlock:^(id<FTAppLifeCycleDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(applicationWillEnterForeground)]) {
            [delegate applicationWillEnterForeground];
        }
    }];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification{
    [self enumerateAppLifecycleDelegatesWithBlock:^(id<FTAppLifeCycleDelegate> delegate) {
        if ([delegate respondsToSelector:@selector(applicationDidEnterBackground)]) {
            [delegate applicationDidEnterBackground];
        }
    }];
}
#endif

@end
