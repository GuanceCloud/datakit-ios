//
//  FTReachability.h
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif
extern NSString *const kFTReachabilityChangedNotification;
/// Current network connection status
typedef NS_ENUM(NSInteger, FTNetworkStatus) {
    /// No network connection
    FTNotReachable = 0,
    /// WiFi
    FTReachableViaWiFi = 2,
    /// Cellular network
    FTReachableViaWWAN = 1
};
typedef void(^NetworkChangeBlock)(void);
/// Network status monitoring tool
@interface FTReachability : NSObject

/// Whether there is a network connection
@property (readonly, nonatomic, assign, getter = isReachable) BOOL reachable;
/// Network status change callback
@property (nonatomic,copy) NetworkChangeBlock networkChanged;

/// Current network status type
@property (nonatomic, copy, readonly) NSString *net;

+(instancetype)reachabilityForInternetConnection;
/// Re-get current network status type
- (NSString *)networkType;

/// Start monitoring network status
- (BOOL)startNotifier;

/// Stop monitoring network status
- (void)stopNotifier;


@end

