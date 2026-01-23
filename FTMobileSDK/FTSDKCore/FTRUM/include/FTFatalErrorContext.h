//
//  FTFatalErrorContext.h
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTErrorDataProtocol.h"

NS_ASSUME_NONNULL_BEGIN
@class FTRUMSessionState;
@protocol FTErrorMonitorInfoProvider;
typedef void (^FTCrashContextChange)(NSDictionary *context);


@interface FTFatalErrorContextModel : NSObject<FTDictionaryConvertible>

@property (nonatomic, copy, readonly, nullable) NSString *appState;
@property (nonatomic, strong, readonly, nullable) FTRUMSessionState *lastSessionState;
@property (nonatomic, strong, readonly, nullable) NSDictionary *lastViewContext;
@property (nonatomic, strong, readonly, nullable) NSDictionary *dynamicContext;
@property (nonatomic, strong, readonly, nullable) NSDictionary *globalAttributes;
@property (nonatomic, strong, readonly, nullable) NSDictionary *errorMonitorInfo;

- (instancetype)initWithAppState:(nullable NSString *)appState
                lastSessionState:(nullable FTRUMSessionState *)lastSessionState
                 lastViewContext:(nullable NSDictionary *)lastViewContext
                  dynamicContext:(nullable NSDictionary *)dynamicContext
                globalAttributes:(nullable NSDictionary *)globalAttributes
                errorMonitorInfo:(nullable NSDictionary *)errorMonitorInfo NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
@end

// Provide Session and View data for crash and longtask
@interface FTFatalErrorContext : NSObject


@property (nonatomic, copy) FTCrashContextChange onChange;

- (instancetype)initWithErrorInfoProvider:(nullable id<FTErrorMonitorInfoProvider>)provider;
- (instancetype)init NS_UNAVAILABLE;

- (void)setAppState:(nullable NSString *)appState;
- (void)setLastSessionState:(nullable FTRUMSessionState *)lastSessionState;
- (void)setLastViewContext:(nullable NSDictionary *)lastViewContext;
- (void)setDynamicContext:(nullable NSDictionary *)dynamicContext;

- (FTFatalErrorContextModel *)currentContextModel;

@end

NS_ASSUME_NONNULL_END
