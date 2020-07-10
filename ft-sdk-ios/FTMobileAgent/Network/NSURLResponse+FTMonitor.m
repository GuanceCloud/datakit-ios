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
        [dict setValue:[self ft_getResponseStatusCode] forKey:FT_NETWORK_CODE];

    }
    if (data&&![self checkIsFileDownLoad]) {
        NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [dict setValue:dataStr forKey:FT_NETWORK_BODY];
    }else{
        [dict setValue:@"" forKey:FT_NETWORK_BODY];
    }
    return dict;
}
- (BOOL)checkIsFileDownLoad{
    NSString *mime = self.MIMEType;
    if ([mime isEqualToString:@"multipart/form-data"]) {
        return YES;
    }
    if ([mime isEqualToString:@"application/javascript"] || [mime isEqualToString:@"application/json"]) {
        return NO;
    }
    if([mime componentsSeparatedByString:@"/"].count>0&&[[[mime componentsSeparatedByString:@"/"] firstObject] isEqualToString:@"text"]){
        return NO;
    }
    return YES;
}
- (NSNumber *)ft_getResponseStatusCode{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self;
    return [NSNumber numberWithInteger:httpResponse.statusCode];
}
@end
