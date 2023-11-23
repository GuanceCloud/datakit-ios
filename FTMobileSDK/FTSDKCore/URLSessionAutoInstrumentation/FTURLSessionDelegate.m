//
//  FTURLSessionDelegate.m
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


#import "FTURLSessionDelegate.h"
#import "FTURLSessionInstrumentation.h"
#import "FTURLSessionInterceptor+Private.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "NSURLSession+FTSwizzler.h"
#import "FTSwizzle.h"
@interface FTURLSessionDelegate()
@property (nonatomic,strong,readwrite) FTURLSessionInstrumentation *instrumentation;
@property (nonatomic,strong) NSSet *interceptedSelectors;
@property (nonatomic,strong) id<NSURLSessionDelegate> actualDelegate;
@property (nonatomic,weak) id<NSURLSessionTaskDelegate> taskDelegate;
@end
@implementation FTURLSessionDelegate
@synthesize ftURLSessionDelegate;
-(instancetype)init{
    return [self initWithRealDelegate:nil];
}
- (instancetype)initWithRealDelegate:(id<NSURLSessionDelegate>)delegate{
    self = [super init];
    if (self) {
        _actualDelegate = delegate;
        _taskDelegate = (id<NSURLSessionTaskDelegate>)delegate;
        _interceptedSelectors = [[NSSet alloc]initWithArray:@[NSStringFromSelector(@selector(URLSession:dataTask:didReceiveData:)),NSStringFromSelector(@selector(URLSession:task:didCompleteWithError:)),NSStringFromSelector(@selector(URLSession:task:didFinishCollectingMetrics:))]];
    }
    return self;
}
-(FTURLSessionDelegate *)ftURLSessionDelegate{
    return self;
}
- (FTURLSessionInstrumentation *)instrumentation{
    return [FTURLSessionInstrumentation sharedInstance];
}
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request{
    NSURLRequest *interceptedRequest = request;
    if(self.requestInterceptor){
        interceptedRequest = self.requestInterceptor(request);
    }
    return [self.instrumentation.interceptor interceptRequest:interceptedRequest];
}
- (void)interceptTask:(NSURLSessionTask *)task{
    [self.instrumentation.interceptor interceptTask:task];
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.instrumentation.interceptor taskReceivedData:dataTask data:data];
    if(self.actualDelegate && [self.actualDelegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]){
        [(id<NSURLSessionDataDelegate>)self.actualDelegate URLSession:session dataTask:dataTask didReceiveData:data];
    }
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    [self.instrumentation.interceptor taskMetricsCollected:task metrics:metrics];
    if(self.actualDelegate && [self.actualDelegate respondsToSelector:@selector(URLSession:task:didFinishCollectingMetrics:)]){
        [self.taskDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [self.instrumentation.interceptor taskCompleted:task error:error extraProvider:self.provider];
    if(self.actualDelegate && [self.actualDelegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]){
        [self.taskDelegate URLSession:session task:task didCompleteWithError:error];
    }
}
#pragma mark ========== Proxy ==========
-(BOOL)respondsToSelector:(SEL)aSelector{
    if([self.interceptedSelectors containsObject:NSStringFromSelector(aSelector)]){
        return YES;
    }
    return (self.actualDelegate?[self.actualDelegate respondsToSelector:aSelector]:NO)||[super respondsToSelector:aSelector];
}
- (id)forwardingTargetForSelector:(SEL)aSelector{
    return [self.interceptedSelectors containsObject:NSStringFromSelector(aSelector)]?nil:self.actualDelegate;
}
#pragma mark ========== interceptor ==========
/// 拦截 Request 修改 request
//+ (void)requestInterceptor:(RequestInterceptor)requestInterceptor{
//    [[FTURLSessionInstrumentation sharedInstance].interceptor setRequestInterceptor:requestInterceptor];
//}
/// 告诉拦截器需要自定义 RUM 资源属性。
//+ (void)rumResourcePropertyProvider:(ResourcePropertyProvider)provider{
//    [[FTURLSessionInstrumentation sharedInstance].interceptor setProvider:provider];
//}

@end
