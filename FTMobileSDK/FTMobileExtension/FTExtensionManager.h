//
//  FTExtensionManager.h
//  FTMobileExtension
//
//  Created by hulilei on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTLoggerConfig.h"
#import "FTExtensionConfig.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTExtensionManager : NSObject
/**
 * @abstract
 * Extension initialization method
 *
 * @param extensionConfig extension configuration items
 */
+ (void)startWithExtensionConfig:(FTExtensionConfig *)extensionConfig;

+ (instancetype)sharedInstance;
/**
 * @abstract
 * Log reporting
 *
 * @param content  log content, can be json string
 * @param status   event level and status, info: prompt, warning: warning, error: error, critical: critical, ok: recovery, default: info
 */
-(void)logging:(NSString *)content status:(FTLogStatus)status;
/// Add custom logs
/// - Parameters:
///   - content: log content, can be json string
///   - status: event level and status
///   - property: event custom properties (optional)
-(void)logging:(NSString *)content status:(FTLogStatus)status property:(nullable NSDictionary *)property;
@end

NS_ASSUME_NONNULL_END
