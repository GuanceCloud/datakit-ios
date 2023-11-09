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
- (instancetype)initWithRealDelegate:(id<NSURLSessionDelegate>)delegate{
    return [self initWithRealDelegate:delegate requestInterceptor:nil extraProvider:nil];
}
- (instancetype)initWithRealDelegate:(id<NSURLSessionDelegate>)delegate requestInterceptor:(RequestInterceptor)requestInterceptor extraProvider:( ResourcePropertyProvider)provider{
    self = [super init];
    if (self) {
        _actualDelegate = delegate;
        _taskDelegate = (id<NSURLSessionTaskDelegate>)delegate;
        _interceptedSelectors = [[NSSet alloc]initWithArray:@[NSStringFromSelector(@selector(URLSession:dataTask:didReceiveData:)),NSStringFromSelector(@selector(URLSession:task:didCompleteWithError:)),NSStringFromSelector(@selector(URLSession:task:didFinishCollectingMetrics:))]];
        self.provider = provider;
        self.requestInterceptor = requestInterceptor;
    }
    return self;
}
-(FTURLSessionDelegate *)ftURLSessionDelegate{
    return self;
}
-(void)setRequestInterceptor:(RequestInterceptor)requestInterceptor{
    [self.instrumentation.interceptor setRequestInterceptor:requestInterceptor];
}
-(void)setProvider:(ResourcePropertyProvider)provider{
  [self.instrumentation.interceptor setProvider:provider];
}
- (FTURLSessionInstrumentation *)instrumentation{
  return [FTURLSessionInstrumentation sharedInstance];
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
  [self.instrumentation.interceptor taskReceivedData:dataTask data:data];
  [(id<NSURLSessionDataDelegate>)self.actualDelegate URLSession:session dataTask:dataTask didReceiveData:data];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
  [self.instrumentation.interceptor taskMetricsCollected:task metrics:metrics];
  [self.taskDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
  [self.instrumentation.interceptor taskCompleted:task error:error];
  [self.taskDelegate URLSession:session task:task didCompleteWithError:error];
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
@end
