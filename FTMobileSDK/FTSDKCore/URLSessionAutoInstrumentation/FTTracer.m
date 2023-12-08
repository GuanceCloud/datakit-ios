//
//  FTTracer.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTTracer.h"
#import "FTDateUtil.h"
#import "NSString+FTAdd.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTURLSessionInterceptor.h"
#import "FTEnumConstant.h"
#import "FTInternalLog.h"
static NSUInteger SkyWalkingSequence = 0.0;

@interface FTTracer ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *skyTraceID;
@property (nonatomic, copy) NSString *skyParentInstance;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) NetworkTraceType traceType;
@end
@implementation FTTracer
@synthesize enableLinkRumData = _enableLinkRumData;
@synthesize enableAutoTrace = _enableAutoTrace;

-(instancetype)initWithSampleRate:(int)sampleRate traceType:(NetworkTraceType)traceType enableAutoTrace:(BOOL)trace enableLinkRumData:(BOOL)link{
    self = [super init];
    if(self){
        _sampleRate = sampleRate;
        _traceType = traceType;
        _enableLinkRumData = link;
        _enableAutoTrace = trace;
    }
    return self;
}
- (NSDictionary *)networkTraceHeaderWithUrl:(NSURL *)url{
    BOOL sampled = [FTBaseInfoHandler randomSampling:self.sampleRate];
    switch (self.traceType) {
        case Jaeger:
            return [self getJaegerHeader:sampled handler:nil];
        case ZipkinMultiHeader:
            return [self getZipkinMultiHeader:sampled handler:nil];
        case DDtrace:
            return [self getDDTraceHeader:sampled handler:nil];
        case ZipkinSingleHeader:
            return [self getZipkinSingleHeader:sampled handler:nil];
        case SkyWalking:
            return [self getSkyWalking_V3Header:sampled url:url handler:nil];
        case Traceparent:
            return [self getTraceparentHeader:sampled handler:nil];
    }
}
- (NSDictionary *)networkTraceHeaderWithUrl:(NSURL *)url handler:(UnpackTraceHeaderHandler)handler{
    BOOL sampled = [FTBaseInfoHandler randomSampling:self.sampleRate];
    switch (self.traceType) {
        case Jaeger:
            return [self getJaegerHeader:sampled handler:handler];
        case ZipkinMultiHeader:
            return [self getZipkinMultiHeader:sampled handler:handler];
        case DDtrace:
            return [self getDDTraceHeader:sampled handler:handler];
        case ZipkinSingleHeader:
            return [self getZipkinSingleHeader:sampled handler:handler];
        case SkyWalking:
            return [self getSkyWalking_V3Header:sampled url:url handler:handler];
        case Traceparent:
            return [self getTraceparentHeader:sampled handler:handler];
    }
}
- (void)unpackTraceHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    switch (self.traceType) {
        case Jaeger:
            return [self unpackJaegerHeader:header handler:handler];
        case ZipkinMultiHeader:
            return [self unpackZipkinMultiHeader:header handler:handler];
        case DDtrace:
            return [self unpackDDTraceHeader:header handler:handler];
        case ZipkinSingleHeader:
            return [self unpackZipkinSingleHeader:header handler:handler];
        case SkyWalking:
            return [self unpackSkyWalking_V3Header:header handler:handler];
        case Traceparent:
            return [self unpackTraceparentHeader:header handler:handler];
    }
}
#pragma mark --------- Jaeger ----------
- (NSDictionary *)getJaegerHeader:(BOOL)sampled handler:(UnpackTraceHeaderHandler)handler{
    NSString *traceID = [self networkTraceID];
    NSString *spanID = [self networkSpanID];
    if(handler){
        handler(traceID,spanID);
    }
    return @{FT_NETWORK_JAEGER_TRACEID:[NSString stringWithFormat:@"%@:%@:0:%@",traceID,spanID,@(sampled)]};
}
-(void)unpackJaegerHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    if([[header allKeys] containsObject:FT_NETWORK_JAEGER_TRACEID]) {
        NSString *traceStr =header[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@":"];
        if (traceAry.count == 4) {
            handler([traceAry firstObject],traceAry[1]);
            return;
        }
    }
    handler(nil,nil);
}
#pragma mark --------- Zipkin ----------
- (NSDictionary *)getZipkinMultiHeader:(BOOL)sampled handler:(UnpackTraceHeaderHandler)handler{
    NSString *traceID = [self networkTraceID];
    NSString *spanID = [self networkSpanID];
    if(handler){
        handler(traceID,spanID);
    }
    return @{FT_NETWORK_ZIPKIN_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
             FT_NETWORK_ZIPKIN_SPANID:spanID,
             FT_NETWORK_ZIPKIN_TRACEID:traceID,
    };
}
- (NSDictionary *)getZipkinSingleHeader:(BOOL)sampled handler:(UnpackTraceHeaderHandler)handler{
    NSString *traceID = [self networkTraceID];
    NSString *spanID = [self networkSpanID];
    if(handler){
        handler(traceID,spanID);
    }
    return @{FT_NETWORK_ZIPKIN_SINGLE_KEY:[NSString stringWithFormat:@"%@-%@-%@",traceID,spanID,[NSString stringWithFormat:@"%d",sampled]]};
}
-(void)unpackZipkinMultiHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_TRACEID]&&[[header allKeys]containsObject:FT_NETWORK_ZIPKIN_SPANID]&&[[header allKeys]containsObject:FT_NETWORK_ZIPKIN_SAMPLED]) {
        NSString *trace = header[FT_NETWORK_ZIPKIN_TRACEID];
        NSString *span = header[FT_NETWORK_ZIPKIN_SPANID];
        handler(trace,span);
    }else{
        handler(nil,nil);
    }
}
-(void)unpackZipkinSingleHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    if([header.allKeys containsObject:FT_NETWORK_ZIPKIN_SINGLE_KEY]){
        NSArray *traceAry = [header[FT_NETWORK_ZIPKIN_SINGLE_KEY] componentsSeparatedByString:@"-"];
        if(traceAry.count == 3){
            NSString *trace = [traceAry firstObject];
            NSString *span = traceAry[1];
            handler(trace,span);
            return;
        }
    }
    handler(nil,nil);
}
#pragma mark --------- DDTRACE ----------
- (NSDictionary *)getDDTraceHeader:(BOOL)sampled handler:(UnpackTraceHeaderHandler)handler{
    NSString *traceId = [NSString stringWithFormat:@"%llu",[self generateUniqueID]];
    NSString *spanId = [NSString stringWithFormat:@"%llu",[self generateUniqueID]];
    NSString *samplingPriority = sampled? @"2":@"-1";
    if(handler){
        handler(traceId,spanId);
    }
    return @{FT_NETWORK_DDTRACE_ORIGIN:@"rum",
             FT_NETWORK_DDTRACE_SPANID:spanId,
             FT_NETWORK_DDTRACE_TRACEID:traceId,
             FT_NETWORK_DDTRACE_SAMPLING_PRIORITY:samplingPriority
    };
}
-(void)unpackDDTraceHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    if ([header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID] &&
        [header.allKeys containsObject:FT_NETWORK_DDTRACE_SPANID]) {
        NSString *trace = [header valueForKey:FT_NETWORK_DDTRACE_TRACEID];
        NSString *span = [header valueForKey:FT_NETWORK_DDTRACE_SPANID];
        handler(trace,span);
    }else{
        handler(nil,nil);
    }
}
- (uint64_t)generateUniqueID{
    uint64_t num;
    arc4random_buf(&num, sizeof(uint64_t));
    return num;
}
#pragma mark --------- SkyWalking ----------
//- (void)getSkyWalking_V2Header:(BOOL)sampled url:(NSURL *)url traceHeader:(TraceHeader)traceHeader{
//    [self.lock lock];
//    NSInteger v2 =  _skywalkingv2 ++;
//    [self.lock unlock];
//    NSString *basetraceId = [NSString stringWithFormat:@"%lu.%@.%lld",(unsigned long)v2,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
//    NSString *urlStr = url.port ? [NSString stringWithFormat:@"#%@:%@",url.host,url.port]: [NSString stringWithFormat:@"#%@",url.host];
//    urlStr = [urlStr ft_base64Encode];
//    NSUInteger seq = [self getSkywalkingSeq];
//    NSString *span = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq];
//    NSString *parentTraceId =[span ft_base64Encode];
//    NSString *trace = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long) seq+1];
//    NSString *traceId =[trace ft_base64Encode];
//    NSString *endPoint = [@"-1" ft_base64Encode];
//    NSDictionary *header = @{FT_NETWORK_SKYWALKING_V2:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,@(v2),@(v2),urlStr,endPoint,endPoint]};
//    traceHeader(trace,span,header);
//}
- (NSDictionary *)getSkyWalking_V3Header:(BOOL)sampled url:(NSURL *)url handler:(UnpackTraceHeaderHandler)handler{
    NSString *baseTraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.skyTraceID,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.skyParentInstance,[FTBaseInfoHandler cellularIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port!=nil ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger sequence = [self getSkyWalkingSequence];
    NSString *spanId = [baseTraceId stringByAppendingFormat:@"%04lu",(unsigned long)sequence];
    NSString *parentTraceId =[spanId ft_base64Encode];
    NSString *trace = [baseTraceId stringByAppendingFormat:@"%04lu",(unsigned long)sequence+1];
    NSString *traceId =[trace ft_base64Encode];
    if(handler){
        handler(traceId,spanId);
    }
    return @{FT_NETWORK_SKYWALKING_V3:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,[FT_DEFAULT_SERVICE_NAME ft_base64Encode],parentServiceInstance,urlPath,urlStr]};
}
-(void)unpackSkyWalking_V3Header:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    if([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V3]){
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V3];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 8) {
            NSString *trace = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            NSString *span = [parentTraceID stringByAppendingString:@"0"];
            handler(trace,span);
            return;
        }
    }
    handler(nil,nil);
}
-(NSUInteger)getSkyWalkingSequence{
    [self.lock lock];
    NSUInteger sequence =  SkyWalkingSequence;
    SkyWalkingSequence += 2 ;
    if (SkyWalkingSequence > 9999) {
        SkyWalkingSequence = 0;
    }
    [self.lock unlock];
    return sequence;
}
-(NSString *)getThreadNumber{
    NSString *str = [NSThread currentThread].description;
    NSString *chooseStr = @"2";
    while ([str containsString:@"="]) {
        NSRange range = [str rangeOfString:@"="];
        NSRange range1 = [str rangeOfString:@","];
        if (range.location != NSNotFound) {
            NSInteger loc = range.location+1;
            NSInteger len = range1.location - loc;
            chooseStr = [str substringWithRange:NSMakeRange(loc, len )];
            break;
        }
    }
    return [chooseStr ft_removeFrontBackBlank];
}

-(NSString *)skyTraceID{
    if (!_skyTraceID) {
        _skyTraceID = [self networkTraceID];
    }
    return _skyTraceID;
}
-(NSString *)skyParentInstance{
    if (!_skyParentInstance) {
        _skyParentInstance = [self networkTraceID];
    }
    return _skyParentInstance;
}
#pragma mark --------- traceParent ----------

- (NSDictionary *)getTraceparentHeader:(BOOL)sample handler:(UnpackTraceHeaderHandler)handler{
    NSString *sampleStr = sample? @"01":@"00";
    NSString *spanID = [self networkSpanID];
    NSString *traceID = [self networkTraceID];
    if(handler){
        handler(traceID,spanID);
    }
    return @{FT_NETWORK_TRACEPARENT_KEY:[NSString stringWithFormat:@"%@-%@-%@-%@",@"00",traceID,spanID,sampleStr]};
}
-(void)unpackTraceparentHeader:(NSDictionary *)headerFields handler:(UnpackTraceHeaderHandler)handler{
    if([headerFields.allKeys containsObject:FT_NETWORK_TRACEPARENT_KEY]){
        NSString *traceStr =headerFields[FT_NETWORK_TRACEPARENT_KEY];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 4) {
            NSString *trace = traceAry[1];
            NSString *span=traceAry[2];
            handler(trace,span);
            return;
        }
    }
    handler(nil,nil);
}
#pragma mark --------- traceID、spanID ----------
- (NSString *)networkTraceID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [uuid lowercaseString];
}
- (NSString *)networkSpanID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [[uuid lowercaseString] ft_md5HashToLower16Bit];
}

@end
