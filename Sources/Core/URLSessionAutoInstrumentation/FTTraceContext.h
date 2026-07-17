//
//  FTTraceContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/31.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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
/// Custom Trace content
@interface FTTraceContext: NSObject
/// traceId, used to associate with rum
@property (nonatomic, copy) NSString *traceId;
/// spanId, used to associate with rum
@property (nonatomic, copy) NSString *spanId;
/// trace data, SDK will add to request.allHTTPHeaderFields after receiving callback
@property (nonatomic, copy) NSDictionary<NSString*,NSString*>*traceHeader;

@end

NS_ASSUME_NONNULL_END
