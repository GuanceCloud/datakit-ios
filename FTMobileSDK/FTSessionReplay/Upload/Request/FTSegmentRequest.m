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
@property (nonatomic, strong) NSArray<FTSegmentJSON*> *segments;
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
    NSMutableArray *array = [NSMutableArray new];
    for (NSData *data in event) {
        FTSegmentJSON *segment = [[FTSegmentJSON alloc]initWithData:data source:@"ios"];
        [array addObject:segment];
    }
    self.segments = array;
    [self mergeSegments];
    self.parameters = parameters;
}
- (void)mergeSegments{
    NSMutableDictionary<NSString*,NSNumber*> *indexes = [NSMutableDictionary new];
    NSMutableArray *segments = [NSMutableArray array];
    for (int i=0; i<self.segments.count; i++) {
        FTSegmentJSON *segment = self.segments[i];
        if(indexes[segment.viewID] != nil){
            int idx = [indexes[segment.viewID] intValue];
            FTSegmentJSON *current = segments[idx];
            [current mergeAnother:segment];
            segments[idx] = current;
        }else{
            [indexes setValue:@(i) forKey:segment.viewID];
            [segments addObject:segment];
        }
    }
    self.segments = segments;
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
            FTSegmentJSON *segment = self.segments[i];
            NSMutableDictionary *segmentJson = [[segment toJSONODict] mutableCopy];
            NSError *error;
            NSData *data = [NSJSONSerialization dataWithJSONObject:segmentJson options:0 error:&error];
            NSMutableData *mutableData = [NSMutableData dataWithData:data];
            [mutableData appendData:[self.multipartFormBody newlineByte]];
//            NSData *compress = [FTCompression compress:mutableData];
            [self.multipartFormBody addFormData:@"segment" filename:[NSString stringWithFormat:@"%@-%@-%lld",segment.sessionID,segment.viewID,segment.start] data:data mimeType:@"application/octet-stream"];
            segmentJson[@"records"] = nil;
            segmentJson[@"raw_segment_size"] = @(data.length);
//            segmentJson[@"compressed_segment_size"] = @(compress.length);
            [segmentJson addEntriesFromDictionary:self.parameters];
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
