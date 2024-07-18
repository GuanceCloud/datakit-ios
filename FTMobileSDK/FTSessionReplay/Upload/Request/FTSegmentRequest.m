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
#import "FTSRRecord.h"
@interface FTSegmentRequest()
@property (nonatomic, strong) id<FTMultipartFormBodyProtocol> multipartFormBody;
@property (nonatomic, strong) NSDictionary *parameters;
//@property (nonatomic, strong) NSArray<FTSegmentJSON*> *segments;
@property (nonatomic, strong) FTEnrichedRecord *segment;
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
- (void)requestWithEvent:(id)event parameters:(NSDictionary *)parameters{
    self.parameters = parameters;
    self.segment = event;
}
-(NSURL *)absoluteURL{
    if (FTNetworkInfoManager.sharedInstance.datakitUrl) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?precision=ms",FTNetworkInfoManager.sharedInstance.datakitUrl,self.path]];
    }
    if(FTNetworkInfoManager.sharedInstance.datawayUrl&&FTNetworkInfoManager.sharedInstance.clientToken){
        return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@?token=%@&to_headless=true&precision=ms",FTNetworkInfoManager.sharedInstance.datawayUrl,self.path,FTNetworkInfoManager.sharedInstance.clientToken]];
    }
    return nil;
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    NSString *date = [[NSDate date] ft_stringWithGMTFormat];
    mutableRequest.HTTPMethod = self.httpMethod;
    //添加header
    [mutableRequest addValue:self.contentType forHTTPHeaderField:@"Content-Type"];
    //设置请求参数
    [mutableRequest setValue:date forHTTPHeaderField:@"Date"];
    [mutableRequest setValue:[NSString stringWithFormat:@"sdk_package_agent=%@",[FTNetworkInfoManager sharedInstance].sdkVersion] forHTTPHeaderField:@"User-Agent"];
    if(self.multipartFormBody){
//        if(self.segments && self.segments.count>0){
//            NSMutableArray *segmentsArray = [NSMutableArray new];
//            for (int i=0; i<self.segments.count; i++) {
//                FTSegmentJSON *segment = self.segments[i];
//                NSMutableDictionary *segmentJson = [[segment toJSONODict] mutableCopy];
//                [segmentJson addEntriesFromDictionary:self.parameters];
//                NSError *error;
//                NSData *data = [NSJSONSerialization dataWithJSONObject:segmentJson options:0 error:&error];
//                NSMutableData *mutableData = [NSMutableData dataWithData:data];
//                [mutableData appendData:[self.multipartFormBody newlineByte]];
//                NSData *compress = [FTCompression compress:mutableData];
//                [self.multipartFormBody addFormData:@"segment" filename:[NSString stringWithFormat:@"%@-%@-%lld",segment.sessionID,segment.viewID,segment.start] data:data mimeType:@"application/octet-stream"];
//                segmentJson[@"records"] = nil;
//                segmentJson[@"index_in_view"] = nil;
//                segmentJson[@"raw_segment_size"] = @(data.length);
//                segmentJson[@"compressed_segment_size"] = @(compress.length);
//                [segmentsArray addObject:segmentJson];
//            }
//            
//            NSError *error;
//            NSData *data = [NSJSONSerialization dataWithJSONObject:segmentsArray options:0 error:&error];
//            [self.multipartFormBody addFormData:@"event"
//                                       filename:@"blob"
//                                           data:data
//                                       mimeType:@"application/json"];
//            mutableRequest.HTTPBody = [self.multipartFormBody build];
//        }
       if (self.segment){
            NSMutableDictionary *segmentJson = [[self.segment toJSONODict] mutableCopy];
            [segmentJson addEntriesFromDictionary:self.parameters];
            NSError *error;
            NSData *data = [NSJSONSerialization dataWithJSONObject:segmentJson options:0 error:&error];
            NSData *compress = [FTCompression compress:data];
            [self.multipartFormBody addFormData:@"segment" filename:[NSString stringWithFormat:@"%@-%lld",self.segment.sessionID,self.segment.start] data:compress mimeType:@"application/octet-stream"];
            [segmentJson removeObjectForKey:@"records"];
            for (NSString *key in segmentJson.allKeys) {
                [self.multipartFormBody addFormField:key value:segmentJson[key]];
            }
            [self.multipartFormBody addFormField:@"raw_segment_size" value:[NSString stringWithFormat:@"%ld",compress.length]];
            mutableRequest.HTTPBody = [self.multipartFormBody build];
        }
    }
    return mutableRequest;
}
@end
