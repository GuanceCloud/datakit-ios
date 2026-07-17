//
//  HttpEngineTestUtil.h
//  App
//
//  Created by hulilei on 2022/9/26.
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
#import <XCTest/XCTest.h>
#import "FTURLSessionDelegate.h"
typedef void (^Completion)(void);
NS_ASSUME_NONNULL_BEGIN
/**
 * Methods using session utility
 * InstrumentationDirect Direct usage
 * InstrumentationInherit Inherit usage
 * InstrumentationProperty Use as property
 */
typedef NS_ENUM(NSUInteger,TestSessionInstrumentationType){
    InstrumentationDirect,
    InstrumentationInherit,
    InstrumentationProperty,
};
@interface HttpEngineTestUtil : NSObject
- (instancetype)initWithSessionInstrumentationType:(TestSessionInstrumentationType)type completion:(Completion)completion;
-(instancetype)initWithSessionInstrumentationType:(TestSessionInstrumentationType)type
                                         provider:(nullable ResourcePropertyProvider)provider
                               requestInterceptor:(nullable RequestInterceptor)requestInterceptor
                                 traceInterceptor:(nullable TraceInterceptor)traceInterceptor
                                       completion:(Completion)completion;
- (NSURLSessionTask *)network;
- (void)network:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (void)urlNetwork;
- (void)urlNetwork:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end


NS_ASSUME_NONNULL_END
