//
//  FTImageRequest.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/6.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTResourceRequest.h"
#import "FTRequestMultipartFormBody.h"
#import "NSDate+FTUtil.h"
#import "FTNetworkInfoManager.h"
#import "FTCompression.h"
#import "FTConstants.h"
#import "FTSRRecord.h"
@interface FTResourceRequest()
@property (nonatomic, strong) NSArray<FTEnrichedResource *> *resources;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, strong) id<FTMultipartFormBodyProtocol> multipartFormBody;
@end
@implementation FTResourceRequest
-(instancetype)init{
    self = [super init];
    if(self){
        self.multipartFormBody = [[FTRequestMultipartFormBody alloc]init];
    }
    return self;
}
-(NSString *)path{
    return @"/v1/write/rum/replay/resource";
}
-(NSString *)contentType{
    return [[NSString alloc]initWithFormat:@"multipart/form-data; boundary=%@",[self.multipartFormBody boundary]];
}
-(void)requestWithEvent:(NSArray *)event parameters:(NSDictionary *)parameters{
    NSMutableArray *resources = [NSMutableArray new];
    for (NSData *data in event) {
        FTEnrichedResource *resource = [[FTEnrichedResource alloc]initWithData:data];
        [resources addObject:resource];
    }
    self.parameters = parameters;
    self.resources = resources;
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    NSString *date =[[NSDate date] ft_stringWithGMTFormat];
    mutableRequest.HTTPMethod = self.httpMethod;
    //添加header
    [mutableRequest addValue:self.contentType forHTTPHeaderField:@"Content-Type"];
    [mutableRequest addValue:@"deflate" forHTTPHeaderField:@"Content-Encoding"];
    //设置请求参数
    [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
    [mutableRequest setValue:[NSString stringWithFormat:@"sdk_package_agent=%@",[FTNetworkInfoManager sharedInstance].sdkVersion] forHTTPHeaderField:@"User-Agent"];
    [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
    if(self.multipartFormBody && self.resources){
        for (FTEnrichedResource *resource in self.resources) {
            [self.multipartFormBody addFormData:@"image" filename:resource.identifier data:resource.data mimeType:@"image/png"];
        }
    }
    NSDictionary *context = @{FT_APP_ID:self.resources[0].appId,
                              @"type":self.resources[0].type
    };
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:context options:0 error:&error];
    [self.multipartFormBody addFormData:@"event"
                               filename:@"blob"
                                   data:data
                               mimeType:@"application/json"];
    
    NSData *compression = [FTCompression encode:[self.multipartFormBody build]];
    mutableRequest.HTTPBody = compression;
    return mutableRequest;
}
@end
