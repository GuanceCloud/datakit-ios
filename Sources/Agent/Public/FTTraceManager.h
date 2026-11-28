//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/11/7.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
