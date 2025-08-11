//
//  FTLogger.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/24.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTLoggerConfig.h"

NS_ASSUME_NONNULL_BEGIN


/// Add custom log interface protocol
@protocol FTLoggerProtocol <NSObject>
@optional
/// Add info type custom log
/// - Parameters:
///   - content: log content
///   - property: custom properties (optional)
- (void)info:(NSString *)content property:(nullable NSDictionary *)property;
/// Add warning type custom log
/// - Parameters:
///   - content: log content
///   - property: custom properties (optional)
- (void)warning:(NSString *)content property:(nullable NSDictionary *)property;
/// Add error type custom log
/// - Parameters:
///   - content: log content
///   - property: custom properties (optional)
- (void)error:(NSString *)content  property:(nullable NSDictionary *)property;
/// Add critical type custom log
/// - Parameters:
///   - content: log content
///   - property: custom properties (optional)
- (void)critical:(NSString *)content property:(nullable NSDictionary *)property;
/// Add ok type custom log
/// - Parameters:
///   - content: log content
///   - property: custom properties (optional)
- (void)ok:(NSString *)content property:(nullable NSDictionary *)property;

/// Add custom log
/// - Parameters:
///   - content: log content
///   - status: log status
- (void)log:(NSString *)content status:(NSString *)status;

/// Add custom log
/// - Parameters:
///   - content: log content
///   - status: log status
///   - property: custom properties (optional)
- (void)log:(NSString *)content status:(NSString *)status property:(nullable NSDictionary *)property;

/// Log input
/// - Parameters:
///   - content: log content, can be json string
///   - statusType: log status
///   - property: custom properties (optional)
- (void)log:(NSString *)content statusType:(FTLogStatus)statusType property:(nullable NSDictionary *)property;
@end

/// Manage custom logs
@interface FTLogger : NSObject<FTLoggerProtocol>
/// Singleton
+ (instancetype)sharedInstance NS_SWIFT_NAME(shared());
/// Shut down logger
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
