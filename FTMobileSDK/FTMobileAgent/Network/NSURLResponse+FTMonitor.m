//
//  NSURLResponse+FTMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "NSURLResponse+FTMonitor.h"
#import "FTConstants.h"
#include <dlfcn.h>
#import "FTMonitorManager.h"
#import "FTLog.h"
@implementation NSURLResponse (FTMonitor)

- (NSDictionary *)ft_getResponseContentDictWithData:(NSData *)data{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if ([self isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self;
        NSDictionary<NSString *, NSString *> *headerFields = httpResponse.allHeaderFields;
        [dict setValue:headerFields forKey:FT_NETWORK_HEADERS];
        [dict setValue:[self ft_getResponseStatusCode] forKey:FT_NETWORK_CODE];
        
    }
    if (data) {
        if([self isAllowedContentType]){
            @try {
                NSError *errors;
                id responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
                [dict setValue:responseObject forKey:FT_NETWORK_BODY];
            } @catch (NSException *exception) {
                [dict setValue:@"" forKey:FT_NETWORK_BODY];
                ZYErrorLog(@"%@",exception);
            }
        }else{
            [dict setValue:@"采集类型外的内容" forKey:FT_NETWORK_BODY];
        }
    }else{
        [dict setValue:@"" forKey:FT_NETWORK_BODY];
    }
    return dict;
}
- (NSDictionary *)ft_getResponseDict{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if ([self isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self;
        NSDictionary<NSString *, NSString *> *headerFields = httpResponse.allHeaderFields;
        [dict setValue:headerFields forKey:FT_NETWORK_HEADERS];
        [dict setValue:[self ft_getResponseStatusCode] forKey:FT_NETWORK_CODE];
        
    }
    return dict;
}
- (BOOL)isAllowedContentType{
    NSString *mime = self.MIMEType;
    __block BOOL allow = NO;
    if([FTMonitorManager sharedInstance].netContentType.count>0){
      return [[FTMonitorManager sharedInstance].netContentType containsObject:mime];
    }
    return allow;
}
- (NSNumber *)ft_getResponseStatusCode{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self;
    return [NSNumber numberWithInteger:httpResponse.statusCode];
}
- (NSString *)ft_getResourceStatusGroup{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self;
    NSInteger statusCode = httpResponse.statusCode;
    NSString *group = nil;
    if (statusCode>=0 && statusCode<1000) {
        NSInteger a = statusCode/100;
        group = [NSString stringWithFormat:@"%ldxx",(long)a];
    }
    return group;
}
@end
