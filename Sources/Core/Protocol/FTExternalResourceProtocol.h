//
//  FTExternalResourceProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/11/17.
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
#import "FTRumResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN

/// Protocol for handling user-defined HTTP Resource data processing
@protocol FTExternalResourceProtocol <NSObject,FTRumResourceProtocol>
/// Get request headers needed for trace
/// - Parameters:
///   - key: Request identifier
///   - url: Request URL
- (nullable NSDictionary *)getTraceHeaderWithUrl:(NSURL *)url;

/// Get request headers needed for trace
/// - Parameters:
///   - key: Request identifier
///   - url: Request URL
- (nullable NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
