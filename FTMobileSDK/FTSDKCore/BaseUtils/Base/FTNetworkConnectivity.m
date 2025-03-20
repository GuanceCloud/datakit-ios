//
//  FTNetworkConnectivity.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTNetworkConnectivity.h"
#import <Network/Network.h>
#import "FTReachability.h"
#import "FTLog+Private.h"
typedef NS_ENUM(NSInteger, FTReachable) {
    yes,
    no,
    maybe,
};
NSString *const FTConnectivityCellular = @"cellular";
NSString *const FTConnectivityWiFi = @"wifi";
NSString *const FTConnectivityNone = @"unreachable";
NSString *const FTConnectivityEthernet = @"ethernet";
NSString *const FTConnectivityUnknown = @"unknown";

@interface FTNetworkConnectivity()
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (nonatomic, copy) NSString *networkType;
@property (nonatomic, strong) FTReachability *reachability;
@property(strong, nonatomic, readonly) NSPointerArray *networkObservers;
@property(strong, nonatomic, readonly) NSLock *observerLock;
@property (atomic, assign) BOOL isNotifying;

@end
@implementation FTNetworkConnectivity{
    nw_path_monitor_t _pathMonitor;
    dispatch_queue_t _monitorQueue;
}
+ (FTNetworkConnectivity *)sharedInstance {
    static FTNetworkConnectivity *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FTNetworkConnectivity alloc] init];
    });
    return instance;
}
-(instancetype)init{
    self = [super init];
    if(self){
        _isConnected = NO;
        _monitorQueue = dispatch_queue_create("com.guance.reachability", NULL);
        _reachability = [FTReachability reachabilityForInternetConnection];
        _networkObservers = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
        _observerLock = [[NSLock alloc] init];
    }
    return self;
}

-(void)start{
    if (self.isNotifying) {
        return;
    }
    self.isNotifying = YES;
#if !TARGET_OS_IOS
    if (@available(iOS 12.0,tvOS 12.0,macOS 10.14, *)) {
        [self startPathMonitorNotifier];
    } else {
        [self startReachabilityNotifier];
    }
#else
    [self startReachabilityNotifier];
#endif
}
-(void)startPathMonitorNotifier API_AVAILABLE(macos(10.14), ios(12.0), tvos(12.0)){
    _pathMonitor = nw_path_monitor_create();
    if (_pathMonitor == nil) {
        FTInnerLogError(@"nw_path_monitor_create failed.");
    }else{
        __weak typeof(self) weakSelf = self;
        nw_path_monitor_set_update_handler(_pathMonitor, ^(nw_path_t path) {
            if (weakSelf == nil) {
                return;
            }
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            nw_path_status_t status = nw_path_get_status(path);
            strongSelf.isConnected = status != nw_path_status_unsatisfied;
            NSString *current = FTConnectivityUnknown;
            if(status == nw_path_status_unsatisfied){
                strongSelf.isConnected = NO;
                current = FTConnectivityNone;
            }else{
                strongSelf.isConnected = YES;
                if (nw_path_uses_interface_type(path,nw_interface_type_wired)) {
                    current = FTConnectivityEthernet;
                }else if (nw_path_uses_interface_type(path,nw_interface_type_wifi)) {
                    current = FTConnectivityWiFi;
                }
            }
            // 网络状态变化时，如果跟上次的网络类型一致则不进行通知
            if(![strongSelf.networkType isEqualToString:current]){
                strongSelf.networkType = current;
                [strongSelf connectivityChanged];
            }
        });
        nw_path_monitor_set_queue(_pathMonitor, _monitorQueue);
        nw_path_monitor_start(_pathMonitor);
    }
}
- (void)startReachabilityNotifier{
    [_reachability startNotifier];
    __weak typeof(self) weakSelf = self;
    _reachability.networkChanged = ^{
        if (weakSelf == nil) {
            return;
        }
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.networkType = strongSelf.reachability.net;
        strongSelf.isConnected = strongSelf.reachability.isReachable;
    };
    self.networkType = self.reachability.net;
    self.isConnected = self.reachability.isReachable;
}
- (void)connectivityChanged{
    [self.observerLock lock];
    for (id observer in self.networkObservers) {
        if ([observer respondsToSelector:@selector(connectivityChanged:typeDescription:)]) {
            [observer connectivityChanged:self.isConnected typeDescription:self.networkType];
        }
    }
    [self.observerLock unlock];
}
- (void)addNetworkObserver:(id<FTNetworkChangeObserver>)observer{
    [self.observerLock lock];
    if (![self.networkObservers.allObjects containsObject:observer]) {
        [self.networkObservers addPointer:(__bridge void *)observer];
    }
    [self.observerLock unlock];
}
- (void)removeNetworkObserver:(id<FTNetworkChangeObserver>)observer{
    [self.observerLock lock];
    for (NSUInteger i=0; i<self.networkObservers.count; i++) {
        if ([self.networkObservers pointerAtIndex:i] == (__bridge void *)observer) {
            [self.networkObservers removePointerAtIndex:i];
            break;
        }
    }
    [self.observerLock unlock];
}
-(void)cancel{
#if TARGET_OS_TV
    if (@available(iOS 12.0,tvOS 12.0,macOS 10.14, *)) {
        nw_path_monitor_cancel(_pathMonitor);
        _pathMonitor = nil;
    } else {
        [_reachability stopNotifier];
    }
#else
    [_reachability stopNotifier];
#endif
    self.isNotifying = YES;
}
- (void)stop {
  [self cancel];
}
- (void)dealloc {
  [self cancel];
}
@end
