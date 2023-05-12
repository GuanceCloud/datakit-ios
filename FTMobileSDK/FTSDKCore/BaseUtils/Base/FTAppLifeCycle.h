//
//  FTAppLifeCycle.h
//  FTMacOSSDK-framework
//
//  Created by 胡蕾蕾 on 2021/9/17.
//

#import <Foundation/Foundation.h>
#import "FTSDKCompat.h"
NS_ASSUME_NONNULL_BEGIN
/// APP 生命周期协议
@protocol FTAppLifeCycleDelegate <NSObject>
@optional

/// App 即将结束
- (void)applicationWillTerminate;

/// App 进入活跃状态
- (void)applicationDidBecomeActive;

/// App 即将失活
- (void)applicationWillResignActive;

#if FT_IOS
/// App 即将进入后台
- (void)applicationWillEnterForeground;
/// App 进入后台
- (void)applicationDidEnterBackground;
#endif

@end
/// App 生命周期监控工具
@interface FTAppLifeCycle : NSObject
/// 单例
+ (instancetype)sharedInstance;
/// 添加遵循 FTAppLifeCycleDelegate 协议的代理类
/// - Parameter delegate: 遵循 FTAppLifeCycleDelegate 协议的代理类
- (void)addAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;
/// 移除遵循 FTAppLifeCycleDelegate 协议的代理类
/// - Parameter delegate: 遵循 FTAppLifeCycleDelegate 协议的代理类
- (void)removeAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
