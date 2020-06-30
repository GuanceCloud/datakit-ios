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

@implementation NSURLResponse (FTMonitor)

- (NSDictionary *)ft_getResponseContentDictWithData:(NSData *)data{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if ([self isKindOfClass:[NSHTTPURLResponse class]]) {
           NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self;
        NSDictionary<NSString *, NSString *> *headerFields = httpResponse.allHeaderFields;
        [dict setValue:headerFields forKey:FT_NETWORK_HEADERS];
    }
    if (data) {
        NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [dict setValue:dataStr forKey:FT_NETWORK_BODY];
       }
    return dict;
}
@end
