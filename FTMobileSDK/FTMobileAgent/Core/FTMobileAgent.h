//
//  FTMobileAgent.h
//  FTMobileAgent
//
//  Created by hulilei on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
#import "FTLoggerConfig.h"
#import "FTRumConfig.h"
#import "FTExternalDataManager.h"
#import "FTResourceMetricsModel.h"
#import "FTResourceContentModel.h"
#import "FTURLSessionDelegate.h"
#import "FTTraceManager.h"
#import "FTLogger.h"
#import "FTRumDatasProtocol.h"
#import "FTRemoteConfigTypeDefs.h"
NS_ASSUME_NONNULL_BEGIN

/// FTMobileSDK
@interface FTMobileAgent : NSObject

-(instancetype) init __attribute__((unavailable("Please use sharedInstance to access")));

#pragma mark ========== init instance ==========
/// Returns the previously initialized singleton.
/// Before calling this method, you must first call the startWithConfigOptions method
+ (instancetype)sharedInstance;
/// SDK initialization method
///
/// Configure basic configuration items when starting the SDK. The necessary configuration items include the FT-GateWay metrics write address.
///
/// The SDK must be initialized in the main thread, otherwise unpredictable problems may occur (such as losing launch events).
/// - Parameter configOptions: SDK basic configuration items.
+ (void)startWithConfigOptions:(FTMobileConfig *)configOptions;

/// Configure RUM Config to enable RUM functionality
///
/// RUM user monitoring, collects user behavior data, supports collecting View, Action, Resource, LongTask, Error. Supports automatic collection and manual addition.
/// - Parameter rumConfigOptions: rum configuration items.
- (void)startRumWithConfigOptions:(FTRumConfig *)rumConfigOptions;
/// Configure Logger Config to enable Logger functionality
///
/// - Parameters:
///   - loggerConfigOptions: logger configuration items.
- (void)startLoggerWithConfigOptions:(FTLoggerConfig *)loggerConfigOptions;

/// Set filter Resource domain
/// - Parameter handler: Determine whether to collect callback, returns YES to collect, NO to filter out
- (void)isIntakeUrl:(BOOL(^)(NSURL *url))handler DEPRECATED_MSG_ATTRIBUTE("Deprecated, please set `resourceUrlHandler` when configuring FTRumConfig as replacement");
/// Configure Trace Config to enable Trace functionality
///
/// - Parameters:
///   - traceConfigOptions: trace configuration items.
- (void)startTraceWithConfigOptions:(FTTraceConfig *)traceConfigOptions;
/// Add custom logs
///
/// - Parameters:
///   - content: log content, can be json string
///   - status: event level and status
-(void)logging:(NSString *)content status:(FTLogStatus)status;

/// Add custom logs
/// - Parameters:
///   - content: log content, can be json string
///   - status: event level and status
///   - property: event custom properties (optional)
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property;

/// Bind user information
///
/// - Parameters:
///   - userId:  user ID
- (void)bindUserWithUserID:(NSString *)userId;

/// Bind user information
///
/// - Parameters:
///   - Id:  user ID
///   - userName: user name
///   - userEmail: user email
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail;
/// Bind user information
///
/// - Parameters:
///   - Id:  user ID
///   - userName: user name
///   - userEmail: user email
///   - extra: user's extra information
- (void)bindUserWithUserID:(NSString *)Id userName:(nullable NSString *)userName userEmail:(nullable NSString *)userEmail extra:(nullable NSDictionary *)extra;

/// Unbind current user
- (void)unbindUser;

/// Add SDK global tags, applies to RUM and Log data
/// - Parameter context: custom data
+ (void)appendGlobalContext:(NSDictionary <NSString*,id>*)context;

/// Add RUM custom tags, applies to RUM data
/// - Parameter context: custom data
+ (void)appendRUMGlobalContext:(NSDictionary <NSString*,id>*)context;

/// Add Log global tags, applies to Log data
/// - Parameter context: custom data
+ (void)appendLogGlobalContext:(NSDictionary <NSString*,id>*)context;

/// Track data cached in App Extension groupIdentifier
/// - Parameters:
///   - groupIdentifier: groupIdentifier
///   - completion: callback after track completion
- (void)trackEventFromExtensionWithGroupIdentifier:(NSString *)groupIdentifier completion:(nullable void (^)(NSString *groupIdentifier, NSArray *events)) completion;

///  Actively sync data
- (void)flushSyncData;

/// Shut down running objects within the SDK
+ (void)shutDown;

/// Clear all data that hasn't been uploaded to the server yet
+ (void)clearAllData;

/// Trigger request to get remote configuration environment variables
/// The minimum update time interval defaults to FTMobileConfig.remoteConfiguration. If the time interval since the last request doesn't meet the setting, no request will be initiated
+ (void)updateRemoteConfig;

/// Trigger request to get remote configuration environment variables
/// - Parameters:
///   - miniUpdateInterval: minimum time interval since last request
///   - completion: request callback
+ (void)updateRemoteConfigWithMiniUpdateInterval:(NSInteger)miniUpdateInterval
                                         completion:(nullable FTRemoteConfigFetchCompletionBlock)completion;
#pragma mark ========== DEPRECATED ==========
/// Trigger request to get remote configuration environment variables
/// - Parameters:
///   - miniUpdateInterval: minimum time interval since last request
///   - callback: request callback
+ (void)updateRemoteConfigWithMiniUpdateInterval:(int)miniUpdateInterval callback:(void (^)(BOOL success, NSDictionary<NSString *, id> * _Nullable config))callback DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -updateRemoteConfigWithMiniUpdateInterval:completion: instead");

/// Unbind current user
- (void)logout DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -unbindUser instead");

/// Shut down running objects within the SDK
/// If the SDK is not initialized, using `[[FTMobileAgent sharedInstance] shutDown]` operation in test environment will cause assertion crash, it's recommended to use class method instead `[FTMobileAgent shutDown]`
- (void)shutDown DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use +shutDown instead");
@end

NS_ASSUME_NONNULL_END
