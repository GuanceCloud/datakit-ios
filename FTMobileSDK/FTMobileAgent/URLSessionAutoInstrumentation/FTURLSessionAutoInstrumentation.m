//
//  URLSessionAutoInstrumentation.m
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


#import "FTURLSessionAutoInstrumentation.h"
#import "NSURLSession+FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTURLSessionInterceptor.h"
#import "FTURLProtocol.h"
#import "FTMobileConfig.h"
#import "FTTracer.h"
@interface FTURLSessionAutoInstrumentation()
@property (nonatomic, assign) BOOL swizzle;
@property (nonatomic, strong) FTURLSessionInterceptor *sessionInterceptor;
@property (nonatomic, strong) FTTracer *tracer;
@end
@implementation FTURLSessionAutoInstrumentation
static FTURLSessionAutoInstrumentation *sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedInstance {
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
- (instancetype)init{
    self = [super init];
    if (self) {
        _sessionInterceptor = [FTURLSessionInterceptor new];
    }
    return self;
}
-(id<FTURLSessionInterceptorDelegate>)interceptor{
    return _sessionInterceptor;
}
-(void)setSdkUrlStr:(NSString *)sdkUrlStr{
    _sdkUrlStr = sdkUrlStr;
    self.interceptor.innerUrl = sdkUrlStr;
}
-(id<FTExternalResourceProtocol>)rumResourceHandler{
    return _sessionInterceptor;
}
-(id<FTTracerProtocol>)tracer{
    return _tracer;
}
- (void)setRUMConfig:(FTRumConfig *)config{
    self.interceptor.enableAutoRumTrack = config.enableTraceUserResource;
    if(config.enableTraceUserResource){
        [self startMonitor];
    }
}
- (void)setTraceConfig:(FTTraceConfig *)config{
    [_sessionInterceptor enableAutoTrace:config.enableAutoTrace];
    [_sessionInterceptor enableLinkRumData:config.enableLinkRumData];
    _tracer = [[FTTracer alloc]initWithConfig:config];
    [_sessionInterceptor setTracer:_tracer];
    if(config.enableAutoTrace){
        [self startMonitor];
    }
}

- (void)startMonitor{
    if (self.swizzle) {
        return;
    }
    self.swizzle = YES;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = NULL;
        if (@available(iOS 13.0, *)) {
            [NSURLSession ft_swizzleMethod:@selector(dataTaskWithURL:) withMethod:@selector(ft_dataTaskWithURL:) error:&error];
            [NSURLSession ft_swizzleMethod:@selector(dataTaskWithRequest:) withMethod:@selector(ft_dataTaskWithRequest:) error:&error];
        }
        [NSURLSession ft_swizzleMethod:@selector(dataTaskWithURL:completionHandler:) withMethod:@selector(ft_dataTaskWithURL:completionHandler:) error:&error];
        [NSURLSession ft_swizzleMethod:@selector(dataTaskWithRequest:completionHandler:) withMethod:@selector(ft_dataTaskWithRequest:completionHandler:) error:&error];
    });
    [FTURLProtocol startMonitor];
    [FTURLProtocol setDelegate:self.interceptor];
}
- (void)resetInstance{
    onceToken = 0;
    sharedInstance =nil;
}
@end
