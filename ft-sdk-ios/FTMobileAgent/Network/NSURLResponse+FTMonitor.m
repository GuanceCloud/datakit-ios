//
//  NSURLResponse+FTMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import "NSURLResponse+FTMonitor.h"
#import "FTConstants.h"
#include <dlfcn.h>
#import "FTMonitorManager.h"
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
        NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [dict setValue:dataStr forKey:FT_NETWORK_BODY];
        }else{
            [dict setValue:@"采集类型外的内容" forKey:FT_NETWORK_BODY];
        }
    }else{
        [dict setValue:@"" forKey:FT_NETWORK_BODY];
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
@end
