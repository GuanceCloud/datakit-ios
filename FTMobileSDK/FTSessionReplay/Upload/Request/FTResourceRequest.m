//
//  FTImageRequest.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/6.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTResourceRequest.h"
#import "FTRequestMultipartFormBody.h"
#import "FTSessionReplayCoreImports.h"
#import "FTCompression.h"
#import "FTSRRecord.h"
#import "FTResourceCheckRequest.h"

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
    return @"/v1/write/rum/replay_assets";
}
-(NSString *)contentType{
    return [[NSString alloc]initWithFormat:@"multipart/form-data; boundary=%@",[self.multipartFormBody boundary]];
}
-(void)requestWithEvents:(NSArray *)events parameters:(NSDictionary *)parameters{
    self.resources = events;
    self.parameters = parameters;
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    if(!self.multipartFormBody || !self.resources || self.resources.count == 0){
        return nil;
    }
    [self addHTTPHeaderFields:mutableRequest packageId:[FTPackageIdGenerator generatePackageId:self.serialNumber count:self.resources.count]];
    
    mutableRequest.HTTPMethod = self.httpMethod;
    
    for (FTEnrichedResource *resource in self.resources) {
        [self.multipartFormBody addFormData:@"files" filename:resource.identifier data:resource.data mimeType:@"application/octet-stream"];
    }
    [self.multipartFormBody addFormField:FT_APP_ID value:self.resources[0].appId];
    
    mutableRequest.HTTPBody = [self.multipartFormBody build];
    return mutableRequest;
}
@end
