//
//  NSURLRequest+FTMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "NSURLRequest+FTMonitor.h"
#import "FTConstants.h"
#import "FTGlobalRumManager.h"
#import <objc/runtime.h>
#import "FTTraceManager.h"
@implementation NSURLRequest (FTMonitor)
-(NSDate *)ftRequestStartDate{
    return objc_getAssociatedObject(self, @"ft_requestStartDate");
}
-(void)setFtRequestStartDate:(NSDate*)startDate{
    objc_setAssociatedObject(self, @"ft_requestStartDate", startDate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSDictionary *)ft_getRequestHeaders{
    NSDictionary<NSString *, NSString *> *headerFields = self.allHTTPHeaderFields;
    NSDictionary<NSString *, NSString *> *cookiesHeader = [self dgm_getCookies];
    [headerFields setValue:self.URL.host forKey:@"Host"];
    if (cookiesHeader.count) {
        NSMutableDictionary *headerFieldsWithCookies = [NSMutableDictionary dictionaryWithDictionary:headerFields];
        [headerFieldsWithCookies addEntriesFromDictionary:cookiesHeader];
        headerFields = [headerFieldsWithCookies copy];
    }
    return headerFields;
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

- (NSURLRequest *)ft_NetworkTrace{
    NSMutableURLRequest *mutableReqeust = [self mutableCopy];
    if([[FTTraceManager sharedInstance] isTraceUrl:mutableReqeust.URL]){
        NSString *identifier =  [NSUUID UUID].UUIDString;
        if([FTTraceManager sharedInstance].enableAutoTrace){
        NSDictionary *traceHeader = [[FTTraceManager sharedInstance] getTraceHeaderWithKey:identifier url:mutableReqeust.URL];
        if (traceHeader && traceHeader.allKeys.count>0) {
            [traceHeader enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
                [mutableReqeust setValue:value forHTTPHeaderField:field];
            }];
            [mutableReqeust setValue:identifier forHTTPHeaderField:@"ft_identifier"];
        }
        }
    }
    return mutableReqeust;
}
@end
