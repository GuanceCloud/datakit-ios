//
//  FTURLSessionInterceptorProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/9/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#ifndef FTURLSessionInterceptorProtocol_h
#define FTURLSessionInterceptorProtocol_h
#import "FTRumResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@protocol FTRumInnerResourceProtocol <FTRumResourceProtocol>
- (void)addResourceWithKey:(NSString *)identifier metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content spanID:(NSString *)spanID traceID:(NSString *)traceID;
@end

@protocol URLSessionInterceptorType<NSObject>
@property (nonatomic, weak) id<FTRumInnerResourceProtocol> innerResourceHandeler;
- (NSURLRequest *)injectTraceHeader:(NSURLRequest *)request;
- (void)taskCreated:(NSURLSessionTask *)task  session:(NSURLSession *)session;
- (void)taskMetricsCollected:(NSURLSessionTask *)task metrics:(NSURLSessionTaskMetrics *)metrics;
- (void)taskReceivedData:(NSURLSessionTask *)task data:(NSData *)data;
- (void)taskCompleted:(NSURLSessionTask *)task error:(NSError *)error;

@end
NS_ASSUME_NONNULL_END
#endif /* FTURLSessionInterceptorProtocol_h */
