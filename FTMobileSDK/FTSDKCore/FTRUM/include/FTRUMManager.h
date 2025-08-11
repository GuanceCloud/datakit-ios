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
