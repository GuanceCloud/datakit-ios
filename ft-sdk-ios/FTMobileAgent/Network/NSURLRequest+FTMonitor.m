//
//  NSURLRequest+FTMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import "NSURLRequest+FTMonitor.h"
#import "FTConstants.h"

@implementation NSURLRequest (FTMonitor)
- (NSString *)ft_getBodyData{
    if ([self checkIsFileUpLoad]) {
        return @"";
    }
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
        return [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
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
- (BOOL)checkIsFileUpLoad{
    if ([self isKindOfClass:NSURLSessionUploadTask.class]) {
        return YES;
    }
    if ([self.HTTPMethod isEqualToString:@"GET"]||[self.HTTPMethod isEqualToString:@"HEAD"]) {
        return NO;
    }
    if([[self.allHTTPHeaderFields allKeys] containsObject:@"Content-Type"]){
        NSString *contentType = self.allHTTPHeaderFields[@"Content-Type"];
        if([contentType containsString:@"multipart/form-data"]){
            return YES;
        }
      
    }
    return NO;
}
@end
