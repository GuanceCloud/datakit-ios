//
//  FTURLSessionDelegate.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/9/13.
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


#import <Foundation/Foundation.h>
#import "FTTraceContext.h"
/// Custom RUM resource property Block
typedef NSDictionary<NSString *,id>* _Nullable (^ResourcePropertyProvider)( NSURLRequest * _Nullable request, NSURLResponse * _Nullable response,NSData *_Nullable data, NSError *_Nullable error);
/// Intercept Request and return modified Request, can be used for custom link tracing
typedef NSURLRequest*_Nonnull(^RequestInterceptor)(NSURLRequest *_Nonnull request);
/// Support custom trace, return TraceContext after confirming interception, return nil if not intercepted
typedef FTTraceContext*_Nullable(^TraceInterceptor)(NSURLRequest *_Nonnull request);
/// Support custom interception of SessionTask Error, return YES after confirming interception, return NO if not intercepted
typedef BOOL (^SessionTaskErrorFilter)(NSError *_Nonnull error);

NS_ASSUME_NONNULL_BEGIN
@class FTURLSessionDelegate;

/// Interface protocol for forwarding 'URLSessionDelegate' calls to 'ftURLSessionDelegate'.
///
/// Must ensure that `ftURLSessionDelegate` calls the required methods
@protocol FTURLSessionDelegateProviding <NSURLSessionDelegate>
/// Automated collection delegate proxy object
///
/// At the same time, ftURLSessionDelegate must implement the following methods for SDK to perform data collection
/// -  `- URLSession:dataTask:didReceiveData:`
/// -  `- URLSession:task:didCompleteWithError:`
/// -  `- URLSession:task:didFinishCollectingMetrics:`
@property (nonatomic, strong) FTURLSessionDelegate *ftURLSessionDelegate;

@end
/// `URLSession` proxy delegate object that supports automated collection.
///
/// All requests made by 'URLSession' using this delegate object will be intercepted by the SDK.
@interface FTURLSessionDelegate : NSObject <NSURLSessionTaskDelegate,NSURLSessionDataDelegate,FTURLSessionDelegateProviding>

/// Intercept Request and return modified Request, can be used for custom link tracing
@property (nonatomic,copy) RequestInterceptor requestInterceptor;

/// Support determining whether to perform custom trace through URLRequest, return TraceContext after confirming interception, return nil if not intercepted
@property (nonatomic,copy) TraceInterceptor traceInterceptor;

/// Tell the interceptor that custom RUM resource properties are needed.
@property (nonatomic,copy) ResourcePropertyProvider provider;

/// Whether to intercept and override SessionTask Error
/// return YES: intercept, network_error will not be added to rum
/// return NO: do not intercept, network_error will be added to rum
@property (nonatomic,copy) SessionTaskErrorFilter errorFilter;

/// Proxy that implements interception of url request process
- (FTURLSessionDelegate *)ftURLSessionDelegate;
@end


NS_ASSUME_NONNULL_END
