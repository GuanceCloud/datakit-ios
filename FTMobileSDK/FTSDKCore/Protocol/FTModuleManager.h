//
//  FTModuleManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/10.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NSString *FTMessageKey NS_STRING_ENUM;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRUMContext;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeySRProperty;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRecordsCountByViewID;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeySessionHasReplay;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyWebViewSR;
@protocol FTMessageReceiver;
@interface FTModuleManager : NSObject
+ (instancetype)sharedInstance;

- (NSDictionary *)getSRProperty;

- (void)postMessage:(NSString *)key message:(NSDictionary *)message;
/// 添加遵循 FTMessageReceiver 协议的代理类
/// - Parameter delegate: 遵循 FTMessageReceiver 协议的代理类
- (void)addMessageReceiver:(id<FTMessageReceiver>)receiver;
/// 移除遵循 FTMessageReceiver 协议的代理类
/// - Parameter delegate: 遵循 FTMessageReceiver 协议的代理类
- (void)removeMessageReceiver:(id<FTMessageReceiver>)receiver;

- (void)registerService:(Protocol *)service instance:(id)instance;

- (id)getRegisterService:(Protocol *)protocol;
@end

NS_ASSUME_NONNULL_END
