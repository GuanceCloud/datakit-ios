//
//  FTTraceHeaderManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTTraceHeaderManager.h"
#import "FTDateUtil.h"
#import "NSString+FTAdd.h"
#import "FTMonitorUtils.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "FTWKWebViewHandler.h"
#import "FTURLProtocol.h"
#import "FTNetworkInfoManager.h"
#import "FTConfigManager.h"
@interface FTTraceHeaderManager ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, copy) NSString *skyTraceId;
@property (nonatomic, copy) NSString *skyParentInstance;
@property (nonatomic, assign) FTNetworkTraceType type;
@property (nonatomic, assign) int samplerate;
@end
@implementation FTTraceHeaderManager{
    NSUInteger _skywalkingSeq;
    NSUInteger _skywalkingv2;
}
+ (instancetype)sharedInstance {
    static FTTraceHeaderManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
-(void)setNetworkTrace:(FTTraceConfig *)traceConfig {
    self.type = traceConfig.networkTraceType;
    self.samplerate = traceConfig.samplerate;
    self.enableLinkRumData = traceConfig.enableLinkRumData;
    self.networkTraceType = traceConfig.networkTraceType;
    if (traceConfig.enableAutoTrace) {
        [FTWKWebViewHandler sharedInstance].enableTrace = YES;
        [FTURLProtocol startMonitor];
    }
    
}
- (void)networkTrackHeaderWithUrl:(NSURL *)url traceHeader:(TraceHeader)traceHeader{

    BOOL sampled = [FTBaseInfoHandler randomSampling:self.samplerate];
    switch (self.type) {
        case FTNetworkTraceTypeJaeger:
            return [self getJaegerHeader:sampled traceHeader:traceHeader];
        case FTNetworkTraceTypeZipkinMultiHeader:
            return [self getZipkinMultiHeader:sampled traceHeader:traceHeader];
        case FTNetworkTraceTypeDDtrace:
            return [self getDDTRACEHeader:sampled traceHeader:traceHeader];
        case FTNetworkTraceTypeZipkinSingleHeader:
            return [self getZipkinSingleHeader:sampled traceHeader:traceHeader];
        case FTNetworkTraceTypeSkywalking:
            return [self getSkyWalking_V3Header:sampled url:url traceHeader:traceHeader];
        case FTNetworkTraceTypeTraceparent:
            return [self getTraceparentHeader:sampled traceHeader:traceHeader];
    }
}

#pragma mark --------- Jaeger ----------
- (void)getJaegerHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [FTTraceHeaderManager networkTraceID];
    NSString *spanid = [FTTraceHeaderManager networkSpanID];
    NSDictionary *header =@{FT_NETWORK_JAEGER_TRACEID:[NSString stringWithFormat:@"%@:%@:0:%@",traceid,spanid,@(sampled)]};
    traceHeader(traceid,spanid,header);
}
#pragma mark --------- Zipkin ----------
- (void)getZipkinMultiHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [FTTraceHeaderManager networkTraceID];
    NSString *spanid = [FTTraceHeaderManager networkSpanID];
    NSDictionary *header = @{FT_NETWORK_ZIPKIN_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
                             FT_NETWORK_ZIPKIN_SPANID:spanid,
                             FT_NETWORK_ZIPKIN_TRACEID:traceid,
                    };
    traceHeader(traceid,spanid,header);
}
- (void)getZipkinSingleHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [FTTraceHeaderManager networkTraceID];
    NSString *spanid = [FTTraceHeaderManager networkSpanID];
    NSDictionary *header =@{FT_NETWORK_ZIPKIN_SINGLE_KEY:[NSString stringWithFormat:@"%@-%@-%@",traceid,spanid,[NSString stringWithFormat:@"%d",sampled]]};
    traceHeader(traceid,spanid,header);
}
#pragma mark --------- DDTRACE ----------
- (void)getDDTRACEHeader:(BOOL)sampled traceHeader:(TraceHeader)traceHeader{
    NSString *traceid = [NSString stringWithFormat:@"%llu",[self generateUniqueID]];
    NSString *spanid = [NSString stringWithFormat:@"%llu",[self generateUniqueID]];
    NSDictionary *header =@{FT_NETWORK_DDTRACE_ORIGIN:@"rum",
                            FT_NETWORK_DDTRACE_SPANID:spanid,
                            FT_NETWORK_DDTRACE_SAMPLED:[NSString stringWithFormat:@"%d",sampled],
                            FT_NETWORK_DDTRACE_TRACEID:traceid,
                            FT_NETWORK_DDTRACE_SAMPLING_PRIORITY:@"1"
                   };
    traceHeader(traceid,spanid,header);
    
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
- (void)getSkyWalking_V3Header:(BOOL)sampled url:(NSURL *)url traceHeader:(TraceHeader)traceHeader{
    NSString *basetraceId = [NSString stringWithFormat:@"%@.%@.%lld",self.skyTraceId,[self getThreadNumber],[FTDateUtil currentTimeMillisecond]];
    NSString *parentServiceInstance = [[NSString stringWithFormat:@"%@@%@",self.skyParentInstance,[FTMonitorUtils cellularIPAddress:YES]] ft_base64Encode];
    NSString *urlStr = url.port ? [NSString stringWithFormat:@"%@:%@",url.host,url.port]: url.host;
    NSString *urlPath = url.path.length>0 ? url.path : @"/";
    urlPath = [urlPath ft_base64Encode];
    urlStr = [urlStr ft_base64Encode];
    NSUInteger seq = [self getSkywalkingSeq];
    NSString *spanid = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq];
    NSString *parentTraceId =[spanid ft_base64Encode];
    NSString *trace = [basetraceId stringByAppendingFormat:@"%04lu",(unsigned long)seq+1];
    NSString *traceId =[trace ft_base64Encode];
    NSDictionary *header = @{FT_NETWORK_SKYWALKING_V3:[NSString stringWithFormat:@"%@-%@-%@-0-%@-%@-%@-%@",@(sampled),traceId,parentTraceId,[FT_DEFAULT_SERVICE_NAME ft_base64Encode],parentServiceInstance,urlPath,urlStr]};
    traceHeader(trace,spanid,header);
}
-(NSUInteger)getSkywalkingSeq{
    [self.lock lock];
    NSUInteger seq =  _skywalkingSeq;
    _skywalkingSeq += 2 ;
    if (_skywalkingSeq > 9999) {
        _skywalkingSeq = 0;
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
        _skyTraceId = [FTTraceHeaderManager networkTraceID];
    }
    return _skyTraceId;
}
-(NSString *)skyParentInstance{
    if (!_skyParentInstance) {
        _skyParentInstance = [FTTraceHeaderManager networkTraceID];
    }
    return _skyParentInstance;
}
#pragma mark --------- traceparent ----------

- (void)getTraceparentHeader:(BOOL)sample traceHeader:(TraceHeader)traceHeader{
    NSString *sampleDescion = sample? @"01":@"00";
    NSString *spanid = [FTTraceHeaderManager networkSpanID];
    NSString *traceID = [FTTraceHeaderManager networkTraceID];
    NSDictionary *header = @{FT_NETWORK_TRACEPARENT_KEY:[NSString stringWithFormat:@"%@-%@-%@-%@",@"00",traceID,spanid,sampleDescion]};
    traceHeader(traceID,spanid,header);
}
#pragma mark --------- traceid、spanid ----------
+(NSString *)networkTraceID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [uuid lowercaseString];
}
+(NSString *)networkSpanID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [[uuid lowercaseString] ft_md5HashToLower16Bit];
}
@end
