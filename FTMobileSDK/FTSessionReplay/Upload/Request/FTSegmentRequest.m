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
#import "FTLog+Private.h"

@interface FTSegmentRequest()
@property (nonatomic, strong) id<FTMultipartFormBodyProtocol> multipartFormBody;
@property (nonatomic, strong) NSDictionary *parameters;
//@property (nonatomic, strong) NSArray<FTSegmentJSON*> *segments;
@property (nonatomic, strong) FTSegmentJSON *segment;
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
    return [[NSString alloc]initWithFormat:@"multipart/form-data; boundary=%@",[self.multipartFormBody boundary]];
}
-(NSString *)userAgent{
    return [[super userAgent] stringByAppendingString:@" (Mode=Replay)"];
}
-(void)requestWithEvents:(NSArray *)events parameters:(NSDictionary *)parameters{
    self.parameters = parameters;
    NSArray *merged = [self mergeSegments:events];
    self.segment = [merged firstObject];
}
- (NSArray *)mergeSegments:(NSArray *)segments{
    NSMutableArray *ori = [NSMutableArray array];
    for (NSData *data in segments) {
        FTSegmentJSON *segment =  [[FTSegmentJSON alloc]initWithData:data];
        [ori addObject:segment];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSMutableDictionary<NSString*,NSNumber*> *indexes = [NSMutableDictionary new];
    for (int i=0; i<ori.count; i++) {
        FTSegmentJSON *segment = ori[i];
        if(indexes[segment.viewID] != nil){
            int idx = [indexes[segment.viewID] intValue];
            FTSegmentJSON *current = result[idx];
            [current mergeAnother:segment];
            result[idx] = current;
        }else{
            [indexes setValue:@(indexes.count) forKey:segment.viewID];
            [result addObject:segment];
        }
    }
    return result;
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
    if (!self.multipartFormBody || !self.segment) {
        return nil;
    }
    // header
    [self addHTTPHeaderFields:mutableRequest packageId:[FTPackageIdGenerator generatePackageId:self.serialNumber count:self.segment.records.count]];
    // method
    mutableRequest.HTTPMethod = self.httpMethod;
    // body
    NSDictionary *bindInfo = self.segment.bindInfo;
    self.segment.bindInfo = nil;
    NSMutableData *mutableData = [NSMutableData dataWithData:[self.segment toJSONData]];
    [mutableData appendData:[self.multipartFormBody newlineByte]];
    NSData *compress = [FTCompression compress:mutableData];
    [self.multipartFormBody addFormData:@"segment" filename:[NSString stringWithFormat:@"%@-%lld",self.segment.sessionID,self.segment.start] data:compress mimeType:@"application/octet-stream"];
    NSMutableDictionary *segmentJson = [NSMutableDictionary new];
    [segmentJson setValue:self.segment.sessionID forKey:@"session_id"];
    [segmentJson setValue:self.segment.viewID forKey:@"view_id"];
    [segmentJson setValue:self.segment.appId forKey:@"app_id"];
    [segmentJson setValue:@(self.segment.hasFullSnapshot) forKey:@"has_full_snapshot"];
    [segmentJson setValue:@(self.segment.recordsCount) forKey:@"records_count"];
    [segmentJson setValue:@(self.segment.end) forKey:@"end"];
    [segmentJson setValue:@(self.segment.start) forKey:@"start"];
    [segmentJson addEntriesFromDictionary:self.parameters];
    if (bindInfo) {
        [segmentJson addEntriesFromDictionary:bindInfo];
    }
    FTInnerLogDebug(@"[Segment Request] segmentJson:%@",segmentJson);
    for (NSString *key in segmentJson.allKeys) {
        [self.multipartFormBody addFormField:key value:segmentJson[key]];
    }
    [self.multipartFormBody addFormField:@"raw_segment_size" value:@(compress.length)];
    mutableRequest.HTTPBody = [self.multipartFormBody build];
    return mutableRequest;
}
@end
