//
//  FTNetworkConnectivity.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTNetworkConnectivity.h"
#import <Network/Network.h>
#import "FTInnerLog.h"
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif
#import "FTConstants.h"

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
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (atomic, copy) NSString *networkType;
@property (nonatomic, strong, readonly) NSPointerArray *networkObservers;
@property (nonatomic, strong, readonly) NSLock *observerLock;
@property (atomic, assign) BOOL isNotifying;
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
@property (nonatomic, strong) CTTelephonyNetworkInfo *networkInfo;
#endif
@property (nonatomic, assign) FTNetworkStatus networkStatus;
@property (atomic, assign) BOOL hasPathStatus;
@property (atomic, assign) BOOL networkAvailable;
@end
@implementation FTNetworkConnectivity{
    nw_path_monitor_t _pathMonitor;
    dispatch_queue_t _monitorQueue;
}
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
        _isConnected = NO;
        _monitorQueue = dispatch_queue_create("com.ft.reachability", NULL);
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
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
    _networkInfo = [FTNetworkConnectivity sharedNetworkInfo];
#endif
    [self startPathMonitorNotifier];
}
-(void)startPathMonitorNotifier{
    _pathMonitor = nw_path_monitor_create();
    if (_pathMonitor == nil) {
        FTInnerLogError(@"nw_path_monitor_create failed.");
    }else{
        __weak typeof(self) weakSelf = self;
        nw_path_monitor_set_update_handler(_pathMonitor, ^(nw_path_t path) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf)  return;
            nw_path_status_t status = nw_path_get_status(path);
            strongSelf.hasPathStatus = YES;
            strongSelf.networkAvailable = status == nw_path_status_satisfied;
            strongSelf.isConnected = status != nw_path_status_unsatisfied;
            FTNetworkStatus networkStatus = FTNetworkStatusUnknown;
            if(status == nw_path_status_unsatisfied){
                strongSelf.isConnected = NO;
                networkStatus = FTNetworkStatusUnknown;
            }else{
                strongSelf.isConnected = YES;
                if (nw_path_uses_interface_type(path,nw_interface_type_wired)) {
                    networkStatus = FTNetworkStatusEthernet;
                }else if (nw_path_uses_interface_type(path,nw_interface_type_wifi)) {
                    networkStatus = FTNetworkStatusWiFi;
                }
            }
            // When network status changes, if it's consistent with the previous network type, no notification is sent
            if( strongSelf.networkStatus != networkStatus ){
                strongSelf.networkStatus = networkStatus;
                [strongSelf connectivityChanged];
            }
        });
        nw_path_monitor_set_queue(_pathMonitor, _monitorQueue);
        nw_path_monitor_start(_pathMonitor);
    }
}
- (NSDictionary<NSString *, id> *)networkResourceFields{
    if (!self.hasPathStatus) {
        return @{};
    }
    return @{FT_KEY_NETWORK_AVAILABLE:@(self.networkAvailable)};
}
-(void)setNetworkStatus:(FTNetworkStatus)networkStatus{
    self.networkType = [self networkTypeWithStatus:networkStatus];
}
- (void)connectivityChanged{
    NSArray *observers = nil;
    [self.observerLock lock];
    @try {
        observers = self.networkObservers.allObjects;
    } @finally {
        [self.observerLock unlock];
    }
    BOOL connected = self.isConnected;
    NSString *typeDescription = [self networkTypeWithStatus:self.networkStatus];
    for (id observer in observers) {
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

            if (_networkInfo && [_networkInfo respondsToSelector:@selector(serviceCurrentRadioAccessTechnology)]) {
                NSDictionary *radioDic = [_networkInfo serviceCurrentRadioAccessTechnology];
                if (radioDic.allKeys.count) {
                    currentStatus = [radioDic objectForKey:radioDic.allKeys[0]];
                }
            }
            
            if (!currentStatus) {
                return FTConnectivityUnknown;
            }
            if (@available(iOS 14.1, *)) {
                NSArray *typeStrings5G = @[CTRadioAccessTechnologyNRNSA,
                                           CTRadioAccessTechnologyNR];
                if ([typeStrings5G containsObject:currentStatus]) {
                    return @"5G";
                }
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

-(void)cancel{
    nw_path_monitor_cancel(_pathMonitor);
    _pathMonitor = nil;
    self.isNotifying = NO;
}
- (void)stop {
  [self cancel];
}
- (void)dealloc {
  [self cancel];
}
@end
