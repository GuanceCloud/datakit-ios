//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/11/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Class that manages trace
///
/// Features:
/// -  Determine whether to perform trace tracking based on URL
/// -  Get trace request header parameters
/// -  Manage traceHandler based on key
@interface FTTraceManager : NSObject
/// Singleton
+ (instancetype)sharedInstance;
/// Get trace request header parameters (deprecated)
/// - Parameters:
///   - key: unique identifier that can determine a specific request
///   - url: request URL
/// - Returns: trace request header parameter dictionary
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:url:] instead");
@end

NS_ASSUME_NONNULL_END
