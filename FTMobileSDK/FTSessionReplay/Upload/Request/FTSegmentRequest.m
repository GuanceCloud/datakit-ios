//
//  FTSessionReplayRequest.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSegmentRequest.h"
#import "FTRequestMultipartFormBody.h"
#import "NSDate+FTUtil.h"
#import "FTNetworkInfoManager.h"
#import "FTCompression.h"
#import "FTSegmentJSON.h"
@interface FTSegmentRequest()
@property (nonatomic, strong) id<FTMultipartFormBodyProtocol> multipartFormBody;
@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, strong) NSArray *segments;
@end
@implementation FTSegmentRequest
-(instancetype)init{
    self = [super init];
    if(self){
        self.multipartFormBody = [[FTRequestMultipartFormBody alloc]init];
    }
    return self;
}
-(NSString *)path{
    return @"/v1/write/rum/replay";
}
-(NSString *)contentType{
    return  [[NSString alloc]initWithFormat:@"multipart/form-data; boundary=%@",[self.multipartFormBody boundary]];
}
- (void)requestWithEvent:(NSArray *)event parameters:(NSDictionary *)parameters{
    self.segments = event;
    self.parameters = parameters;
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    NSString *date =[[NSDate date] ft_stringWithGMTFormat];
    mutableRequest.HTTPMethod = self.httpMethod;
    //添加header
    [mutableRequest addValue:self.contentType forHTTPHeaderField:@"Content-Type"];
    //设置请求参数
    [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
    [mutableRequest setValue:[NSString stringWithFormat:@"sdk_package_agent=%@",[FTNetworkInfoManager sharedInstance].sdkVersion] forHTTPHeaderField:@"User-Agent"];
    if(self.multipartFormBody && self.segments){
        NSMutableArray *segmentsArray = [NSMutableArray new];
        for (int i=0; i<self.segments.count; i++) {
            FTSegmentJSON *segment = [[FTSegmentJSON alloc]initWithData:self.segments[i] source:@"ios"];
            NSMutableDictionary *segmentJson = [[segment toJSONODict] mutableCopy];
            NSError *error;
            NSData *data = [NSJSONSerialization dataWithJSONObject:segmentJson options:0 error:&error];
            NSMutableData *mutableData = [NSMutableData dataWithData:data];
            [mutableData appendData:[self.multipartFormBody newlineByte]];
            NSData *compress = [FTCompression compress:mutableData];
            [self.multipartFormBody addFormData:@"segment" filename:[NSString stringWithFormat:@"file%d",i] data:compress mimeType:@"application/octet-stream"];
            segmentJson[@"records"] = nil;
            segmentJson[@"raw_segment_size"] = @(data.length);
            segmentJson[@"compressed_segment_size"] = @(compress.length);
            [segmentsArray addObject:segmentJson];
        }
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:segmentsArray options:0 error:&error];
        [self.multipartFormBody addFormData:@"event" 
                                   filename:@"blob"
                                       data:data
                                   mimeType:@"application/json"];
        mutableRequest.HTTPBody = [self.multipartFormBody build];
    }
    return mutableRequest;
}
@end
