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
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRecordsCountByViewID;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeySessionHasReplay;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyWebViewSR;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRumError;

@protocol FTMessageReceiver;
@interface FTModuleManager : NSObject
+ (instancetype)sharedInstance;
- (void)postMessage:(NSString *)key messageBlock:(nullable NSDictionary * (^)(void))messageBlock;
- (void)postMessage:(NSString *)key message:(NSDictionary *)message;
- (void)postMessage:(NSString *)key message:(NSDictionary *)message sync:(BOOL)sync;

/// Add delegate class that conforms to FTMessageReceiver protocol
/// - Parameter delegate: Delegate class that conforms to FTMessageReceiver protocol
- (void)addMessageReceiver:(id<FTMessageReceiver>)receiver;
/// Remove delegate class that conforms to FTMessageReceiver protocol
/// - Parameter delegate: Delegate class that conforms to FTMessageReceiver protocol
- (void)removeMessageReceiver:(id<FTMessageReceiver>)receiver;

- (void)registerService:(Protocol *)service instance:(id)instance;

- (id)getRegisterService:(Protocol *)protocol;
@end

NS_ASSUME_NONNULL_END
