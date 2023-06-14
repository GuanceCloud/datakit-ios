//
//  FTReachability.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif
extern NSString *const kFTReachabilityChangedNotification;
/// 当前网络连接状态
typedef NS_ENUM(NSInteger, FTNetworkStatus) {
    /// 无网络连接
    FTNotReachable = 0,
    /// WiFi
    FTReachableViaWiFi = 2,
    /// 蜂窝网络
    FTReachableViaWWAN = 1
};
typedef void(^NetworkChangeBlock)(void);
/// 网络状态监听工具
@interface FTReachability : NSObject

/// 是否有网络连接
@property (readonly, nonatomic, assign, getter = isReachable) BOOL reachable;
/// 网络状态改变回调
@property (nonatomic,copy) NetworkChangeBlock networkChanged;

/// iOS下 是否允许在移动网络状态下进行网络传输
@property (nonatomic, assign) BOOL reachableOnWWAN;

/// 当前网络状态类型
@property (nonatomic, copy, readonly) NSString *net;
/// 单例
+ (instancetype)sharedInstance;
/// 重新获取当前网络状态类型
- (NSString *)networkType;

/// 开始监听网络状态
-(BOOL)startNotifier;

/// 停止监听网络状态
- (void)stopNotifier;


@end

