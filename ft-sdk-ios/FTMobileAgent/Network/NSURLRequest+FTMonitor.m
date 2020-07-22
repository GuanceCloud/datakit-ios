//
//  NSURLRequest+FTMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import "NSURLRequest+FTMonitor.h"
#import "FTConstants.h"
#import "FTMonitorManager.h"

@implementation NSURLRequest (FTMonitor)
- (NSString *)ft_getBodyData:(BOOL)allow{
    NSData *bodyData = self.HTTPBody;
    if (self.HTTPBody == nil) {
        if (self.HTTPBodyStream) {
            NSInputStream *stream = self.HTTPBodyStream;
            NSMutableData *data = [[NSMutableData alloc] init];
            [stream open];
            size_t bufferSize = 4096;
            uint8_t *buffer = malloc(bufferSize);
            if (buffer == NULL) {
                return @"";
            }
            while ([stream hasBytesAvailable]) {
                NSInteger bytesRead = [stream read:buffer maxLength:bufferSize];
                if (bytesRead > 0 && stream.streamError == nil) {
                    NSData *readData = [NSData dataWithBytes:buffer length:bytesRead];
                    [data appendData:readData];
                } else{
                    break;
                }
            }
            free(buffer);
            bodyData = [data copy];
            [stream close];
        }
    } else {
        bodyData = self.HTTPBody;
    }
    if (bodyData) {
        if(allow){
            return [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
        }else{
            return @"采集类型外的内容";
        }
    }
    return @"";
}
- (NSString *)ft_getLineStr{
    //HTTP-Version 暂无法获取
    NSString *lineStr = [NSString stringWithFormat:@"%@ %@ \r\n", self.HTTPMethod, self.URL.path];
    return lineStr;
}


- (NSDictionary *)ft_getRequestContentDict{
    NSDictionary<NSString *, NSString *> *headerFields = self.allHTTPHeaderFields;
    NSDictionary<NSString *, NSString *> *cookiesHeader = [self dgm_getCookies];
    [headerFields setValue:self.URL.host forKey:@"Host"];
    if (cookiesHeader.count) {
        NSMutableDictionary *headerFieldsWithCookies = [NSMutableDictionary dictionaryWithDictionary:headerFields];
        [headerFieldsWithCookies addEntriesFromDictionary:cookiesHeader];
        headerFields = [headerFieldsWithCookies copy];
    }
    NSMutableDictionary *dict =@{@"method":self.HTTPMethod,
                                 FT_NETWORK_HEADERS:headerFields,
                                 @"url":self.URL.absoluteString,
    }.mutableCopy;
    
    return dict;
}
- (NSDictionary<NSString *, NSString *> *)dgm_getCookies {
    NSDictionary<NSString *, NSString *> *cookiesHeader;
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *cookies = [cookieStorage cookiesForURL:self.URL];
    if (cookies.count) {
        cookiesHeader = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    }
    return cookiesHeader;
}
- (NSString *)ft_getOperationName{
    return [NSString stringWithFormat:@"%@/http",self.HTTPMethod];
}
- (NSString *)ft_getNetworkTraceId{
    NSDictionary *header = self.allHTTPHeaderFields;
    if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_TRACEID]) {
        return header[FT_NETWORK_ZIPKIN_TRACEID];
        
    }
    if ([[header allKeys] containsObject:FT_NETWORK_JAEGER_TRACEID]) {
        NSString *trace =header[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [trace componentsSeparatedByString:@":"];
        if (traceAry.count == 4) {
            return  [traceAry firstObject];
        }
        return nil;
    }
    return nil;
}
- (NSString *)ft_getNetworkSpanID{
    NSDictionary *header = self.allHTTPHeaderFields;
    if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_SPANID]) {
        return header[FT_NETWORK_ZIPKIN_SPANID];
    }
    if ([[header allKeys] containsObject:FT_NETWORK_JAEGER_TRACEID]) {
        NSString *trace =header[FT_NETWORK_ZIPKIN_SPANID];
        NSArray *traceAry = [trace componentsSeparatedByString:@":"];
        if (traceAry.count == 4) {
            return  traceAry[1];
        }
        return nil;
    }
    return nil;
}
- (void)ft_getNetworkTraceingDatas:(void (^)(NSString *traceId, NSString *spanID,BOOL sampled))handler{
    NSDictionary *header = self.allHTTPHeaderFields;
    NSString *trace,*span,*sampling;
    if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_TRACEID]) {
        trace = header[FT_NETWORK_ZIPKIN_TRACEID];
    }
    if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_SPANID]) {
        span = header[FT_NETWORK_ZIPKIN_SPANID];
    }
    if ([[header allKeys]containsObject:FT_NETWORK_ZIPKIN_SPANID]) {
        sampling = header[FT_NETWORK_ZIPKIN_SAMPLED] ;
    }
    if ([[header allKeys] containsObject:FT_NETWORK_JAEGER_TRACEID]) {
        NSString *trace =header[FT_NETWORK_JAEGER_TRACEID];
        NSArray *traceAry = [trace componentsSeparatedByString:@":"];
        if (traceAry.count == 4) {
            trace = [traceAry firstObject];
            span =traceAry[1];
            sampling = [traceAry lastObject];
        }
        
    }
    if (handler) {
        handler(trace,span,[sampling boolValue]);
    }
}

- (BOOL)ft_isAllowedContentType{
     BOOL allow = NO;
    if([FTMonitorManager sharedInstance].netContentType.count>0){
    if([[self.allHTTPHeaderFields allKeys] containsObject:@"Content-Type"]){
        NSString *contentType = self.allHTTPHeaderFields[@"Content-Type"];
        NSArray *array = [contentType componentsSeparatedByString:@","];
        if (array.count == 1) {
            return [[FTMonitorManager sharedInstance].netContentType containsObject:[array firstObject]];
        }else{
            for (NSInteger i = 0; i<array.count; i++) {
                NSString *mime = array[i];
                allow = NO;
                if ([mime containsString:@"/"]) {
                    allow = [[FTMonitorManager sharedInstance].netContentType containsObject:[array firstObject]];
                }else{
                    allow = YES;
                }
                if (allow == NO) {
                    break;
                }
            }
        }
    }
    }
    return allow;
}
@end
