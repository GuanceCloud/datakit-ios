//
//  FTNetworkConnectivity.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/18.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTNetworkConnectivity.h"
#import <Network/Network.h>
#import "FTInnerLog.h"
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif
#import "FTConstants.h"
#import <os/lock.h>

NSString *const FTConnectivityCellular = @"cellular";
NSString *const FTConnectivityWiFi = @"wifi";
NSString *const FTConnectivityNone = @"unreachable";
NSString *const FTConnectivityEthernet = @"ethernet";
NSString *const FTConnectivityUnknown = @"unknown";
typedef NS_ENUM(NSInteger, FTNetworkStatus) {
    /// No network connection
    FTNetworkStatusNotReachable = 0,
    /// Cellular network
    FTNetworkStatusWWAN = 1,
    /// WiFi
    FTNetworkStatusWiFi = 2,
    /// Ethernet
    FTNetworkStatusEthernet = 3,
    /// Unknown
    FTNetworkStatusUnknown = 4,
};
@interface FTNetworkConnectivity()
@property (nonatomic, strong, readonly) NSPointerArray *networkObservers;
@property (nonatomic, strong, readonly) NSLock *observerLock;
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
@property (nonatomic, strong) CTTelephonyNetworkInfo *networkInfo;
#endif
@property (nonatomic, assign) FTNetworkStatus networkStatus;
@end
@implementation FTNetworkConnectivity{
    nw_path_monitor_t _pathMonitor;
    dispatch_queue_t _monitorQueue;
    // The lock only protects state, never Network/CoreTelephony calls or observers.
    os_unfair_lock _stateLock;
    BOOL _isNotifying;
    BOOL _isConnected;
    BOOL _hasPathStatus;
    BOOL _networkAvailable;
    NSString *_networkType;
    NSUInteger _generation;
    NSUInteger _pathMonitorGeneration; // Accessed on _monitorQueue.
}
@synthesize networkStatus = _networkStatus;
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
+ (CTTelephonyNetworkInfo *)sharedNetworkInfo {
    static CTTelephonyNetworkInfo *networkInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    });
    return networkInfo;
}
#endif
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
        _stateLock = OS_UNFAIR_LOCK_INIT;
        _isConnected = NO;
        _monitorQueue = dispatch_queue_create("com.ft.reachability", NULL);
        _networkObservers = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
        _observerLock = [[NSLock alloc] init];
    }
    return self;
}

- (BOOL)isCurrentGeneration:(NSUInteger)generation {
    os_unfair_lock_lock(&_stateLock);
    BOOL current = _isNotifying && _generation == generation;
    os_unfair_lock_unlock(&_stateLock);
    return current;
}
- (void)start {
    os_unfair_lock_lock(&_stateLock);
    if (_isNotifying) {
        os_unfair_lock_unlock(&_stateLock);
        return;
    }
    _isNotifying = YES;
    NSUInteger generation = ++_generation;
    os_unfair_lock_unlock(&_stateLock);

    __weak typeof(self) weakSelf = self;
    dispatch_async(_monitorQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (![strongSelf isCurrentGeneration:generation]) return;
        [strongSelf startPathMonitorNotifierForGeneration:generation];
    });
}
- (void)startPathMonitorNotifierForGeneration:(NSUInteger)generation {
    // Creation, startup, cancellation and path callbacks share one serial queue.
    if (_pathMonitor) {
        nw_path_monitor_cancel(_pathMonitor);
        _pathMonitor = nil;
    }
    nw_path_monitor_t monitor = nw_path_monitor_create();
    if (!monitor) {
        os_unfair_lock_lock(&_stateLock);
        if (_generation == generation) _isNotifying = NO;
        os_unfair_lock_unlock(&_stateLock);
        FTInnerLogError(@"nw_path_monitor_create failed.");
        return;
    }
    if (![self isCurrentGeneration:generation]) {
        nw_path_monitor_cancel(monitor);
        return;
    }
    _pathMonitor = monitor;
    _pathMonitorGeneration = generation;
    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (![strongSelf isCurrentGeneration:generation]) return;
        [strongSelf updatePath:path generation:generation];
    });
    nw_path_monitor_set_queue(monitor, _monitorQueue);
    nw_path_monitor_start(monitor);
}
- (void)updatePath:(nw_path_t)path generation:(NSUInteger)generation {
    nw_path_status_t status = nw_path_get_status(path);
    // Preserve the existing connected/available definitions: a path requiring
    // a connection is connected here, but is not yet available for a resource.
    BOOL connected = status != nw_path_status_unsatisfied;
    BOOL available = status == nw_path_status_satisfied;
    FTNetworkStatus networkStatus = FTNetworkStatusUnknown;
    if (connected) {
        if (nw_path_uses_interface_type(path, nw_interface_type_wired)) {
            networkStatus = FTNetworkStatusEthernet;
        } else if (nw_path_uses_interface_type(path, nw_interface_type_wifi)) {
            networkStatus = FTNetworkStatusWiFi;
        } else if (nw_path_uses_interface_type(path, nw_interface_type_cellular)) {
            networkStatus = FTNetworkStatusWWAN;
        }
    }
    NSString *networkType = [self networkTypeWithStatus:networkStatus];
    os_unfair_lock_lock(&_stateLock);
    if (!_isNotifying || _generation != generation) {
        os_unfair_lock_unlock(&_stateLock);
        return;
    }
    BOOL changed = _networkStatus != networkStatus || _isConnected != connected || ![_networkType isEqualToString:networkType];
    _hasPathStatus = YES;
    _networkAvailable = available;
    _isConnected = connected;
    _networkStatus = networkStatus;
    _networkType = networkType;
    os_unfair_lock_unlock(&_stateLock);
    if (changed) {
        [self notifyObserversWithConnected:connected typeDescription:networkType generation:generation];
    }
}
- (BOOL)isConnected {
    os_unfair_lock_lock(&_stateLock);
    BOOL connected = _isConnected;
    os_unfair_lock_unlock(&_stateLock);
    return connected;
}
- (NSString *)networkType {
    os_unfair_lock_lock(&_stateLock);
    NSString *type = _networkType;
    os_unfair_lock_unlock(&_stateLock);
    return type;
}
- (NSDictionary<NSString *, id> *)networkResourceFields {
    os_unfair_lock_lock(&_stateLock);
    BOOL hasPathStatus = _hasPathStatus;
    BOOL available = _networkAvailable;
    os_unfair_lock_unlock(&_stateLock);
    // No network_available field until the first real path update.
    return hasPathStatus ? @{FT_KEY_NETWORK_AVAILABLE:@(available)} : @{};
}
- (FTNetworkStatus)networkStatus {
    os_unfair_lock_lock(&_stateLock);
    FTNetworkStatus status = _networkStatus;
    os_unfair_lock_unlock(&_stateLock);
    return status;
}
- (void)setNetworkStatus:(FTNetworkStatus)networkStatus {
    NSString *type = [self networkTypeWithStatus:networkStatus];
    os_unfair_lock_lock(&_stateLock);
    _networkStatus = networkStatus;
    _networkType = type;
    os_unfair_lock_unlock(&_stateLock);
}
- (void)connectivityChanged {
    os_unfair_lock_lock(&_stateLock);
    BOOL connected = _isConnected;
    NSString *type = _networkType;
    os_unfair_lock_unlock(&_stateLock);
    [self notifyObserversWithConnected:connected typeDescription:type generation:0];
}
- (void)notifyObserversWithConnected:(BOOL)connected typeDescription:(NSString *)typeDescription generation:(NSUInteger)generation {
    NSArray *observers = nil;
    [self.observerLock lock];
    @try {
        observers = self.networkObservers.allObjects;
    } @finally {
        [self.observerLock unlock];
    }
    for (id observer in observers) {
        // A callback can stop/restart monitoring or remove an observer.
        if (generation && ![self isCurrentGeneration:generation]) return;
        if ([observer respondsToSelector:@selector(connectivityChanged:typeDescription:)]) {
            [observer connectivityChanged:connected typeDescription:typeDescription];
        }
    }
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
- (NSString *)networkTypeWithStatus:(FTNetworkStatus)status{
    switch (status) {
        case FTNetworkStatusNotReachable:
            return FTConnectivityNone;
            break;
        case FTNetworkStatusWWAN:{
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
            NSArray *typeStrings2G = @[CTRadioAccessTechnologyEdge,
                                       CTRadioAccessTechnologyGPRS,
                                       CTRadioAccessTechnologyCDMA1x];
            NSArray *typeStrings3G = @[CTRadioAccessTechnologyHSDPA,
                                       CTRadioAccessTechnologyWCDMA,
                                       CTRadioAccessTechnologyHSUPA,
                                       CTRadioAccessTechnologyCDMAEVDORev0,
                                       CTRadioAccessTechnologyCDMAEVDORevA,
                                       CTRadioAccessTechnologyCDMAEVDORevB,
                                       CTRadioAccessTechnologyeHRPD];
            
            NSArray *typeStrings4G = @[CTRadioAccessTechnologyLTE];
            
            NSString *currentStatus = nil;

            // Wi-Fi/ethernet startup must not initialize CoreTelephony.
            if (!_networkInfo) _networkInfo = [[self class] sharedNetworkInfo];
            if (_networkInfo && [_networkInfo respondsToSelector:@selector(serviceCurrentRadioAccessTechnology)]) {
                NSDictionary *radioDic = [_networkInfo serviceCurrentRadioAccessTechnology];
                if (radioDic.allKeys.count) {
                    currentStatus = [radioDic objectForKey:radioDic.allKeys[0]];
                }
            }
            
            if (!currentStatus) {
                return FTConnectivityUnknown;
            }
            NSArray *typeStrings5G = @[CTRadioAccessTechnologyNRNSA,
                                       CTRadioAccessTechnologyNR];
            if ([typeStrings5G containsObject:currentStatus]) {
                return @"5G";
            }
            if ([typeStrings4G containsObject:currentStatus]) {
                return @"4G";
            } else if ([typeStrings3G containsObject:currentStatus]) {
                return @"3G";
            } else if ([typeStrings2G containsObject:currentStatus]) {
                return @"2G";
            } else {
                return FTConnectivityUnknown;
            }
#endif
            return FTConnectivityUnknown;
        }
            break;
        case FTNetworkStatusWiFi:
            return FTConnectivityWiFi;
            break;
            
        case FTNetworkStatusEthernet:
            return FTConnectivityEthernet;
            break;
        case FTNetworkStatusUnknown:
            return FTConnectivityUnknown;
            break;
    }
    return @"unreachable";
}

- (void)cancel {
    os_unfair_lock_lock(&_stateLock);
    _isNotifying = NO;
    NSUInteger generation = ++_generation;
    os_unfair_lock_unlock(&_stateLock);
    __weak typeof(self) weakSelf = self;
    dispatch_async(_monitorQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        // A newer start may have been enqueued before this cancellation block.
        if (strongSelf->_pathMonitor && strongSelf->_pathMonitorGeneration < generation) {
            nw_path_monitor_cancel(strongSelf->_pathMonitor);
            strongSelf->_pathMonitor = nil;
        }
    });
}
- (void)stop {
    [self cancel];
}
- (void)dealloc {
    // Work blocks/handlers hold only weak references; no queue work can use
    // this instance once deallocation starts.
    if (_pathMonitor) nw_path_monitor_cancel(_pathMonitor);
}
@end
