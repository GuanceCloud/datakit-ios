//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import "FTEnumConstant.h"
#import "FTErrorDataProtocol.h"
#import "FTRumDatasProtocol.h"
#import "FTRumResourceProtocol.h"
#import "FTLinkRumDataProvider.h"
@class FTRumConfig,FTResourceMetricsModel,FTResourceContentModel,FTRUMMonitor;

NS_ASSUME_NONNULL_BEGIN
/// App launch type
typedef NS_ENUM(NSUInteger, FTLaunchType) {
    /// Hot launch
    FTLaunchHot,
    /// Cold launch
    FTLaunchCold,
    /// Warm launch, system preloads before APP launch
    FTLaunchWarm
};
@interface FTRUMManager : FTRUMHandler<FTRumResourceProtocol,FTErrorDataDelegate,FTRumDatasProtocol,FTLinkRumDataProvider>
@property (nonatomic, assign) FTAppState appState;
@property (atomic,copy,readwrite) NSString *viewReferrer;
#pragma mark - init -
-(instancetype)initWithRumDependencies:(FTRUMDependencies *)dependencies;

-(void)notifyRumInit;
#pragma mark - resource -
/// HTTP request start
///
/// - Parameters:
///   - key: Request identifier
- (void)startResourceWithKey:(NSString *)key;
/// HTTP request start
/// - Parameters:
///   - key: Request identifier
///   - property: Custom event properties (optional)
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

/// HTTP request data
///
/// - Parameters:
///   - key: Request identifier
///   - metrics: Request-related performance properties
///   - content: Request-related data
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;
/// HTTP request end
///
/// - Parameters:
///   - key: Request identifier
- (void)stopResourceWithKey:(NSString *)key;
/// HTTP request end
/// - Parameters:
///   - key: Request identifier
///   - property: Custom event properties (optional)
- (void)stopResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;
#pragma mark - webView js -

/// Add WebView data
/// - Parameters:
///   - measurement: measurement description
///   - tags: tags description
///   - fields: fields description
///   - tm: tm description
- (void)addWebViewData:(NSString *)measurement tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;
#pragma mark - view -
/**
 * Create page
 * @param viewName     Page name
 * @param loadTime     Page load time
 */
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime;
/**
 * Enter page, viewId managed internally
 * @param viewName        Page name
 */
-(void)startViewWithName:(NSString *)viewName;
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property;
/**
 * Enter page
 * @param viewId          Page id
 * @param viewName        Page name
 */
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(nullable NSDictionary *)property;

/// Leave page
-(void)stopView;
/**
 * Leave page
 * @param viewId         Page id
 */
-(void)stopViewWithViewID:(nullable NSString *)viewId property:(nullable NSDictionary *)property;
/**
 * Leave page
 */
-(void)stopViewWithProperty:(nullable NSDictionary *)property;

#pragma mark - Action -

/// Start RUM Action.
///
/// RUM will bind Resource, Error, LongTask events that this Action may trigger. Avoid adding multiple times within 0.1s. Only one Action can be associated with the same View at the same time. New Actions will be discarded if the previous Action hasn't ended.
/// Does not interfere with Actions added by `addAction:actionType:property` method.
///
/// - Parameters:
///   - actionName: Event name
///   - actionType: Event type
///   - property: Custom event properties (optional)
- (void)startAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;

/// Add Action event. No duration, no discard logic
///
/// Does not interfere with RUM Actions started by `startAction:actionType:property:`.
/// - Parameters:
///   - actionName: Event name
///   - actionType: Event type
///   - property: Custom event properties (optional)
- (void)addAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;
/**
 * App launch
 * @param type      Launch type
 * @param duration  Launch duration
 */
- (void)addLaunch:(FTLaunchType)type launchTime:(NSDate*)time duration:(NSNumber *)duration;

#pragma mark - Error / Long Task -
/// Crash
/// @param type Error type: java_crash/native_crash/abort/ios_crash
/// @param message Error message
/// @param stack Error stack
- (void)addErrorWithType:(nonnull NSString *)type message:(nonnull NSString *)message stack:(nonnull NSString *)stack;
/**
 * Crash
 * @param type       Error type: java_crash/native_crash/abort/ios_crash
 * @param message    Error message
 * @param stack      Error stack
 * @param property   Event properties (optional)
 */
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;

- (void)addErrorWithType:(nonnull NSString *)type message:(nonnull NSString *)message stack:(nonnull NSString *)stack date:(NSDate *)date;
/// Freeze
/// @param stack Freeze stack
/// @param duration Freeze duration
- (void)addLongTaskWithStack:(nonnull NSString *)stack duration:(nonnull NSNumber *)duration startTime:(long long)time;
/**
 * Freeze
 * @param stack      Freeze stack
 * @param duration   Freeze duration
 * @param property   Event properties (optional)
 */
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration startTime:(long long)time property:(nullable NSDictionary *)property;
#pragma mark - get LinkRumData -

/// Wait for all rum processing data to be processed
- (void)syncProcess;
@end

NS_ASSUME_NONNULL_END
