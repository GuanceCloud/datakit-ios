//
//  FTRequest.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTRequest.h"
#import "NSDate+FTUtil.h"
#import "FTNetworkInfoManager.h"
#import "FTRecordModel.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTDataCompression.h"
#import "FTLog+Private.h"
#import "FTEnumConstant.h"
@interface FTRequest()
@property (nonatomic, strong) NSArray <FTRecordModel *> *events;

@end
@implementation FTRequest
+(FTRequest * _Nullable)createRequestWithEvents:(NSArray *)events type:(NSString *)type{
    if ([type isEqualToString:FT_DATA_TYPE_RUM]) {
        return [[FTRumRequest alloc]initWithEvents:events];
    }else if ([type isEqualToString:FT_DATA_TYPE_LOGGING]){
        return [[FTLoggingRequest alloc]initWithEvents:events];
    }
    return nil;
}
-(instancetype)initWithEvents:(NSArray<FTRecordModel *> *)events{
    self = [super init];
    if(self){
        self.events = events;
    }
    return self;
}
-(NSURL *)absoluteURL{
    if (FTNetworkInfoManager.sharedInstance.datakitUrl) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",FTNetworkInfoManager.sharedInstance.datakitUrl,self.path]];
    }
    if(FTNetworkInfoManager.sharedInstance.datawayUrl&&FTNetworkInfoManager.sharedInstance.clientToken){
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?token=%@&to_headless=true",FTNetworkInfoManager.sharedInstance.datawayUrl,self.path,FTNetworkInfoManager.sharedInstance.clientToken]];
    }
    return nil;
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
-(NSString *)serialNumber{
    return nil;
}
-(BOOL)enableDataIntegerCompatible{
    return FTNetworkInfoManager.sharedInstance.enableDataIntegerCompatible;
}
-(HttpRequestCompression)compression{
    return FTNetworkInfoManager.sharedInstance.compression;
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
     NSString *date =[[NSDate date] ft_stringWithGMTFormat];
     mutableRequest.HTTPMethod = self.httpMethod;
     //添加header
     [mutableRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
     [mutableRequest addValue:self.contentType forHTTPHeaderField:@"Content-Type"];
     [mutableRequest addValue:@"charset=utf-8" forHTTPHeaderField:@"Content-Type"];
     [mutableRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
     //设置请求参数
     [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
     [mutableRequest setValue:[NSString stringWithFormat:@"sdk_package_agent=%@",[FTNetworkInfoManager sharedInstance].sdkVersion] forHTTPHeaderField:@"User-Agent"];
     [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
     
    if (self.requestBody&&self.events) {
        NSString *packageId = [NSString stringWithFormat:@"%@.%@.%lu",self.serialNumber,FTNetworkInfoManager.sharedInstance.processID,(unsigned long)self.events.count];
        NSString *body = [self.requestBody getRequestBodyWithEventArray:self.events packageId:packageId enableIntegerCompatible:self.enableDataIntegerCompatible];
        mutableRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    }
    return [self compression:mutableRequest];
}
- (NSMutableURLRequest *)compression:(NSMutableURLRequest *)request{
    switch (self.compression) {
        case None:
            break;
        case Deflate:{
            [request setValue:@"deflate" forHTTPHeaderField:@"Content-Encoding"];
            NSData *data = [FTDataCompression deflate:request.HTTPBody];
            if (data) {
                request.HTTPBody = data;
            }else{
                FTInnerLogError(@"Failed to compress request payload \n- url: %@\n- uncompressed-size: %lu",request.URL,(unsigned long)request.HTTPBody.length);
            }
        }
            break;
        case Gzip:{
            [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
            NSData *data = [FTDataCompression gzip:request.HTTPBody];
            if (data) {
                request.HTTPBody = data;
            }else{
                FTInnerLogError(@"Failed to compress request payload \n- url: %@\n- uncompressed-size: %lu",request.URL,(unsigned long)request.HTTPBody.length);
            }
        }
            break;
        default:
            break;
    }
    return request;
}
@end
@implementation FTLoggingRequest
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/logging";
}
-(NSString *)serialNumber{
    return [FTBaseInfoHandler logRequestSerialNumber];
}
@end
@implementation FTRumRequest
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/rum";
}
-(NSString *)serialNumber{
    return [FTBaseInfoHandler rumRequestSerialNumber];
}
@end
