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

NS_ASSUME_NONNULL_BEGIN
@class FTURLSessionDelegate,FTURLSessionAutoInstrumentation;

/// 转发 'URLSessionDelegate' 调用到 'ftURLSessionDelegate'的接口协议。
///
///  使用示例
///  ```objc
///  @interface InstrumentationPropertyClass:NSObject<NSURLSessionDataDelegate,FTURLSessionDelegateProviding>
///  @property (nonatomic, strong) FTURLSessionDelegate *ftURLSessionDelegate;
///  @end
///  @implementation InstrumentationPropertyClass
///  - (nonnull FTURLSessionDelegate *)ftURLSessionDelegate {
///      if(!_ftURLSessionDelegate){
///          _ftURLSessionDelegate = [[FTURLSessionDelegate alloc]init];
///      }
///      return _ftURLSessionDelegate;
///  }
///  -(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
///      [self.ftURLSessionDelegate URLSession:session dataTask:dataTask didReceiveData:data];
///  }
///  -(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
///      [self.ftURLSessionDelegate URLSession:session task:task didCompleteWithError:error];
///  }
///  -(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
///      [self.ftURLSessionDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
///  }
///  @end
///  ```
@protocol FTURLSessionDelegateProviding <NSURLSessionDelegate>
/// 自动化采集的委托代理对象
///
/// 同时，必须要让 ftURLSessionDelegate 实现以下方法， SDK 才能进行数据采集
/// -  `- URLSession:dataTask:didReceiveData:`
/// -  `- URLSession:task:didCompleteWithError:`
/// -  `- URLSession:task:didFinishCollectingMetrics:`
///
/// 使用参考： ``FTMobileAgent/FTURLSessionDelegateProviding`` 中提供的使用示例

@property (nonatomic, strong) FTURLSessionDelegate *ftURLSessionDelegate;

@end
/// `URLSession` 支持自动化采集的代理委托对象。
///
/// 所有使用这个委托对象的 'URLSession' 所发出的请求都将被 SDK 拦截。
@interface FTURLSessionDelegate : NSObject <NSURLSessionTaskDelegate,NSURLSessionDataDelegate,FTURLSessionDelegateProviding>
/// 具体实现 采集 rum 数据 与 trace 功能的类
@property (nonatomic, strong) FTURLSessionAutoInstrumentation *instrumentation;

/// 实现拦截 url 请求过程的代理
- (FTURLSessionDelegate *)ftURLSessionDelegate;
@end


NS_ASSUME_NONNULL_END
