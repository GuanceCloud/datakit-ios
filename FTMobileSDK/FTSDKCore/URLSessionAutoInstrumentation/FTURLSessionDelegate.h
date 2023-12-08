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
/// 自定义 RUM 资源属性 Block
typedef NSDictionary* _Nullable (^ResourcePropertyProvider)( NSURLRequest * _Nullable request, NSURLResponse * _Nullable response,NSData *_Nullable data, NSError *_Nullable error);
/// 拦截 Request ，返回修改后的 Request，可用于自定义链路追踪
typedef NSURLRequest*_Nonnull(^RequestInterceptor)(NSURLRequest *_Nonnull request);

NS_ASSUME_NONNULL_BEGIN
@class FTURLSessionDelegate;

/// 转发 'URLSessionDelegate' 调用到 'ftURLSessionDelegate'的接口协议。
///
/// 必须确保 `ftURLSessionDelegate` 调用所需的方法
@protocol FTURLSessionDelegateProviding <NSURLSessionDelegate>
/// 自动化采集的委托代理对象
///
/// 同时，必须要让 ftURLSessionDelegate 实现以下方法， SDK 才能进行数据采集
/// -  `- URLSession:dataTask:didReceiveData:`
/// -  `- URLSession:task:didCompleteWithError:`
/// -  `- URLSession:task:didFinishCollectingMetrics:`
@property (nonatomic, strong) FTURLSessionDelegate *ftURLSessionDelegate;

@end
/// `URLSession` 支持自动化采集的代理委托对象。
///
/// 所有使用这个委托对象的 'URLSession' 所发出的请求都将被 SDK 拦截。
@interface FTURLSessionDelegate : NSObject <NSURLSessionTaskDelegate,NSURLSessionDataDelegate,FTURLSessionDelegateProviding>

/// 拦截 Request 返回修改后的 Request，可用于自定义链路追踪
@property (nonatomic,copy) RequestInterceptor requestInterceptor;

/// 告诉拦截器需要自定义 RUM 资源属性。
@property (nonatomic,copy) ResourcePropertyProvider provider;

/// 实现拦截 url 请求过程的代理
- (FTURLSessionDelegate *)ftURLSessionDelegate;
@end


NS_ASSUME_NONNULL_END
