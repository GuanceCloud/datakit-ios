//
//  FTImageRequest.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/6.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTImageRequest.h"
#import "FTRequestImageBody.h"
@interface FTImageRequest()
@property (nonatomic, strong) NSArray *files;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, strong) id<FTRequestImageBodyProtocol> imageRequestBody;
@end
@implementation FTImageRequest
-(instancetype)initRequestWithFiles:(NSArray*)files parameters:(NSDictionary *)parameters{
    self = [super init];
    if(self){
        self.files = files;
        self.parameters = parameters;
        self.imageRequestBody = [[FTRequestImageBody alloc]init];
    }
    return self;
}
-(NSString *)path{
    return @"/v1/write/rum/replay/resource";
}
-(NSString *)contentType{
    return  [[NSString alloc]initWithFormat:@"multipart/form-data; boundary=%@",[self.imageRequestBody boundary]];
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    mutableRequest.HTTPMethod = self.httpMethod;
    [mutableRequest addValue:self.contentType forHTTPHeaderField:@"Content-Type"];
    if (self.imageRequestBody&&self.files.count>0) {
        NSData *body = [self.imageRequestBody getRequestBodyWithImageDatas:self.files parameters:self.parameters];
        [mutableRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
        mutableRequest.HTTPBody = body;
    }
    return mutableRequest;
}
@end
