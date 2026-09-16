//
//  NSURLSessionTask+FTSwizzler.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/1/2.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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
@class FTVisitorIDRequestSnapshot;

@interface NSURLSessionTask (FTSwizzler)
@property (nonatomic, assign) BOOL ft_hasCompletion;
/// Whether Visitor ID matching has already been evaluated for this task.
@property (nonatomic, assign) BOOL ft_visitorIDWasEvaluated;
/// Visitor ID captured on the first eligible resume. Retained for repeated resume and request correlation.
@property (nonatomic, strong, nullable) FTVisitorIDRequestSnapshot *ft_visitorIDSnapshot;

- (id<NSURLSessionDelegate>)ft_delegate;

- (BOOL)ft_isSupportedForInstrumentation;
/// Returns YES for system URLSession WebSocket tasks when the runtime supports them.
- (BOOL)ft_isWebSocketTask;
/// Restores ws/wss from the original request URL, falling back to the current request when absent.
- (nullable NSURL *)ft_webSocketResourceURL;
@end

NS_ASSUME_NONNULL_END
