//
//  HttpEngineTestUtil.h
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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
