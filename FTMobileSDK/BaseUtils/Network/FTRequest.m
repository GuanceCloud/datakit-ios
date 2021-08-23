//
//  FTRequest.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTRequest.h"
#import "FTRequestBody.h"
#import "FTDateUtil.h"
#import "FTConfigManager.h"
@interface FTRequest()
@property (nonatomic, strong) NSArray <FTRecordModel *> *events;

@end
@implementation FTRequest
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events type:(FTDataType)type{
    FTRequest *request = nil;
    switch (type) {
        case FTDataTypeRUM:
            request = [[FTRumRequest alloc]initWithEvents:events];
            break;
        case FTDataTypeLOGGING:
            request = [[FTLoggingRequest alloc]initWithEvents:events];
            break;
        case FTDataTypeTRACING:
            request = [[FTTracingRequest alloc]initWithEvents:events];
            break;
        case FTDataTypeObject:
            request = [[FTObjectRequest alloc]initWithEvents:events];
            break;
    }
    return request;
}
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super init];
    if(self){
        self.events = events;
    }
    return self;
}
-(NSURL *)absoluteURL{
    if (!FTConfigManager.sharedInstance.trackConfig.metricsUrl) {
        return nil;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",FTConfigManager.sharedInstance.trackConfig.metricsUrl,self.path]];
    return url;
}
-(NSString *)contentType{
    return @"text/plain";
}
-(NSString *)httpMethod{
    return @"POST";
}
-(NSString *)path{
    return nil;
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
     NSString *date =[FTDateUtil currentTimeGMT];
     mutableRequest.HTTPMethod = self.httpMethod;
     //添加header
     [mutableRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
     [mutableRequest addValue:self.contentType forHTTPHeaderField:@"Content-Type"];
     [mutableRequest addValue:@"charset=utf-8" forHTTPHeaderField:@"Content-Type"];
     [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
     //设置请求参数
     [mutableRequest setValue:FTConfigManager.sharedInstance.trackConfig.XDataKitUUID forHTTPHeaderField:@"X-Datakit-UUID"];
     [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
     [mutableRequest setValue:[NSString stringWithFormat:@"sdk_package_agent=%@",[FTConfigManager sharedInstance].sdkVersion] forHTTPHeaderField:@"User-Agent"];
     [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
     
    if (self.requestBody&&self.events) {
        NSString *body = [self.requestBody getRequestBodyWithEventArray:self.events];
        mutableRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    }
     return mutableRequest;
}
@end
@implementation FTLoggingRequest
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super init];
    if(self){
        self.events = events;
    }
    return self;
}
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/logging";
}
-(NSString *)contentType{
    return @"text/plain";
}
@end
@implementation FTRumRequest
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super init];
    if(self){
        self.events = events;
    }
    return self;
}
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/rum";
}
-(NSString *)contentType{
    return @"text/plain";
}

@end
@implementation FTTracingRequest
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super init];
    if(self){
        self.events = events;
    }
    return self;
}
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/tracing";
}
-(NSString *)contentType{
    return @"text/plain";
}
@end
@implementation FTObjectRequest
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super init];
    if(self){
        self.events = events;
    }
    return self;
}
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestObjectBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/object";
}
-(NSString *)contentType{
    return @"application/json";
}

@end
