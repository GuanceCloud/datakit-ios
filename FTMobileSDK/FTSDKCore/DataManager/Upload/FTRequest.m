//
//  FTRequest.m
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/5.
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
#import <objc/runtime.h>
@interface FTRequest()

@end
@implementation FTRequest
+(void)initialize{
    if (self == [FTRequest class]) return;
    NSString *prefix = NSStringFromClass(self);
    self.serialGenerator = [[FTSerialNumberGenerator alloc] initWithPrefix:prefix];
}
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
    return @"text/plain;charset=UTF-8";
}
-(NSString *)httpMethod{
    return @"POST";
}
-(NSString *)path{
    return nil;
}
- (NSString *)userAgent{
    return [NSString stringWithFormat:@"%@/%@",FT_USER_AGENT_NAME,[FTNetworkInfoManager sharedInstance].sdkVersion];
}
-(nullable NSString *)serialNumber{
    return [[self classSerialGenerator] getCurrentSerialNumber];
}
- (FTSerialNumberGenerator *)classSerialGenerator{
    return [[self class] serialGenerator];
}
-(BOOL)enableDataIntegerCompatible{
    return FTNetworkInfoManager.sharedInstance.enableDataIntegerCompatible;
}
-(BOOL)compression{
    return FTNetworkInfoManager.sharedInstance.compression;
}
+ (FTSerialNumberGenerator *)serialGenerator {
    FTSerialNumberGenerator *generator = objc_getAssociatedObject(self, _cmd);
    if (!generator) {
        generator = [[FTSerialNumberGenerator alloc] init];
        objc_setAssociatedObject(self, _cmd, generator, OBJC_ASSOCIATION_RETAIN);
    }
    return generator;
}

+ (void)setSerialGenerator:(FTSerialNumberGenerator *)serialGenerator {
    objc_setAssociatedObject(self, @selector(serialGenerator), serialGenerator, OBJC_ASSOCIATION_RETAIN);
}
- (void)addHTTPHeaderFields:(NSMutableURLRequest *)mutableRequest packageId:(NSString *)packageId{
    NSString *date =[[NSDate date] ft_stringWithGMTFormat];
    [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
    if(self.contentType){
        [mutableRequest setValue:self.contentType forHTTPHeaderField:@"Content-Type"];
    }
    [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
    [mutableRequest setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    [mutableRequest setValue:[NSString stringWithFormat:@"rumm-%@",packageId] forHTTPHeaderField:@"X-Pkg-Id"];
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    if (!self.requestBody || !self.events) {
        return nil;
    }
    //Set header
    NSString *packageId = [FTPackageIdGenerator generatePackageId:self.serialNumber count:self.events.count];
    [self addHTTPHeaderFields:mutableRequest packageId:packageId];
    //Set request method
    mutableRequest.HTTPMethod = self.httpMethod;
    //body
    NSString *body = [self.requestBody getRequestBodyWithEventArray:self.events packageId:packageId enableIntegerCompatible:self.enableDataIntegerCompatible];
    mutableRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    return [self compression:mutableRequest];
}
- (NSMutableURLRequest *)compression:(NSMutableURLRequest *)request{
    if(self.compression){
        NSData *data = [FTDataCompression deflate:request.HTTPBody];
        if (data) {
            request.HTTPBody = data;
            [request setValue:@"deflate" forHTTPHeaderField:@"Content-Encoding"];
        }else{
            FTInnerLogError(@"Failed to compress request payload \n- url: %@\n- uncompressed-size: %lu",request.URL,(unsigned long)request.HTTPBody.length);
        }
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
@end
@implementation FTRumRequest
-(id<FTRequestBodyProtocol>)requestBody{
    return [[FTRequestLineBody alloc]init];
}
-(NSString *)path{
    return @"/v1/write/rum";
}
@end
