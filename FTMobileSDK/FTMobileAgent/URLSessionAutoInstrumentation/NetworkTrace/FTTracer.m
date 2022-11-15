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
#import "FTMonitorUtils.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTURLProtocol.h"
#import "FTURLSessionInterceptor.h"
#import "FTMobileConfig.h"
static NSUInteger SkywalkingSeq = 0.0;

@interface FTTracer ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *skyTraceId;
@property (nonatomic, copy) NSString *skyParentInstance;
@property (nonatomic, assign) int samplerate;
@property (nonatomic, assign) FTNetworkTraceType networkTraceType;
@end
@implementation FTTracer
-(instancetype)initWithConfig:(FTTraceConfig *)config{
    self = [super init];
    if (self) {
        _samplerate = config.samplerate;
        _networkTraceType = config.networkTraceType;
    }
    return self;
}
- (NSDictionary *)networkTraceHeaderWithUrl:(NSURL *)url{
    BOOL sampled = [FTBaseInfoHandler randomSampling:self.samplerate];
    switch (self.networkTraceType) {
        case FTNetworkTraceTypeJaeger:
            return [self getJaegerHeader:sampled];
        case FTNetworkTraceTypeZipkinMultiHeader:
            return [self getZipkinMultiHeader:sampled];
        case FTNetworkTraceTypeDDtrace:
            return [self getDDTRACEHeader:sampled];
        case FTNetworkTraceTypeZipkinSingleHeader:
            return [self getZipkinSingleHeader:sampled];
        case FTNetworkTraceTypeSkywalking:
            return [self getSkyWalking_V3Header:sampled url:url];
        case FTNetworkTraceTypeTraceparent:
            return [self getTraceparentHeader:sampled];
    }
}

- (void)unpackTraceHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    switch (self.networkTraceType) {
        case FTNetworkTraceTypeJaeger:
            return [self unpackJaegerHeader:header handler:handler];
        case FTNetworkTraceTypeZipkinMultiHeader:
            return [self unpackZipkinMultiHeader:header handler:handler];
        case FTNetworkTraceTypeDDtrace:
            return [self unpackDDTRACEHeader:header handler:handler];
        case FTNetworkTraceTypeZipkinSingleHeader:
            return [self unpackZipkinSingleHeader:header handler:handler];
        case FTNetworkTraceTypeSkywalking:
            return [self unpackSkyWalking_V3Header:header handler:handler];
        case FTNetworkTraceTypeTraceparent:
            return [self unpackTraceparentHeader:header handler:handler];
    }
}
#pragma mark --------- Jaeger ----------
- (NSDictionary *)getJaegerHeader:(BOOL)sampled{
    NSString *traceid = [self networkTraceID];
    NSString *spanid = [self networkSpanID];
    return @{FT_NETWORK_JAEGER_TRACEID:[NSString stringWithFormat:@"%@:%@:0:%@",traceid,spanid,@(sampled)]};
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
- (NSDictionary *)getZipkinMultiHeader:(BOOL)sampled{
    NSString *traceid = [self networkTraceID];
    NSString *spanid = [self networkSpanID];
    return @{FT_NETWORK_ZIPKIN_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
             FT_NETWORK_ZIPKIN_SPANID:spanid,
             FT_NETWORK_ZIPKIN_TRACEID:traceid,
    };
}
- (NSDictionary *)getZipkinSingleHeader:(BOOL)sampled{
    NSString *traceid = [self networkTraceID];
    NSString *spanid = [self networkSpanID];
    return @{FT_NETWORK_ZIPKIN_SINGLE_KEY:[NSString stringWithFormat:@"%@-%@-%@",traceid,spanid,[NSString stringWithFormat:@"%d",sampled]]};
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
- (NSDictionary *)getDDTRACEHeader:(BOOL)sampled{
    NSString *traceid = [NSString stringWithFormat:@"%llu",[self generateUniqueID]];
    NSString *spanid = [NSString stringWithFormat:@"%llu",[self generateUniqueID]];
    return @{FT_NETWORK_DDTRACE_ORIGIN:@"rum",
             FT_NETWORK_DDTRACE_SPANID:spanid,
             FT_NETWORK_DDTRACE_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
             FT_NETWORK_DDTRACE_TRACEID:traceid,
             FT_NETWORK_DDTRACE_SAMPLING_PRIORITY:@"1"
    };
}
-(void)unpackDDTRACEHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    if ([header.allKeys containsObject:FT_NETWORK_DDTRACE_SAMPLED] && [header.allKeys containsObject:FT_NETWORK_DDTRACE_TRACEID] &&
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
- (NSDictionary *)getSkyWalking_V3Header:(BOOL)sampled url:(NSURL *)url{
    NSString *basetraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.skyTraceId,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.skyParentInstance,[FTMonitorUtils cellularIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port!=nil ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *spanid = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq];
    NSString *parentTraceId =[spanid ft_base64Encode];
    NSString *trace = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq+1];
    NSString *traceId =[trace ft_base64Encode];
    return @{FT_NETWORK_SKYWALKING_V3:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,[FT_DEFAULT_SERVICE_NAME ft_base64Encode],parentServiceInstance,urlPath,urlStr]};
}
-(void)unpackSkyWalking_V3Header:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler{
    if([header.allKeys containsObject:FT_NETWORK_SKYWALKING_V2]){
        NSString *traceStr =header[FT_NETWORK_SKYWALKING_V2];
        NSArray *traceAry = [traceStr componentsSeparatedByString:@"-"];
        if (traceAry.count == 9) {
            NSString *trace = [traceAry[1] ft_base64Decode];
            NSString *parentTraceID=[traceAry[2] ft_base64Decode];
            NSString *span = [parentTraceID stringByAppendingString:@"0"];
            handler(trace,span);
            return;
        }
    }
    handler(nil,nil);
}
-(NSUInteger)getSkywalkingSeq{
    [self.lock lock];
    NSUInteger seq =  SkywalkingSeq;
    SkywalkingSeq += 2 ;
    if (SkywalkingSeq > 9999) {
        SkywalkingSeq = 0;
    }
    [self.lock unlock];
    return seq;
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

-(NSString *)skyTraceId{
    if (!_skyTraceId) {
        _skyTraceId = [self networkTraceID];
    }
    return _skyTraceId;
}
-(NSString *)skyParentInstance{
    if (!_skyParentInstance) {
        _skyParentInstance = [self networkTraceID];
    }
    return _skyParentInstance;
}
#pragma mark --------- traceparent ----------

- (NSDictionary *)getTraceparentHeader:(BOOL)sample{
    NSString *sampleDescion = sample? @"01":@"00";
    NSString *spanid = [self networkSpanID];
    NSString *traceID = [self networkTraceID];
    return @{FT_NETWORK_TRACEPARENT_KEY:[NSString stringWithFormat:@"%@-%@-%@-%@",@"00",traceID,spanid,sampleDescion]};
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
#pragma mark --------- traceid、spanid ----------
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
