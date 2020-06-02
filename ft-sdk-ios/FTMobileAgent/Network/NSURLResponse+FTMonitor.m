//
//  NSURLResponse+FTMonitor.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import "NSURLResponse+FTMonitor.h"
#include <dlfcn.h>
typedef CFHTTPMessageRef (*DMURLResponseGetHTTPResponse)(CFURLRef response);

@implementation NSURLResponse (FTMonitor)

- (NSString *)ft_getStatusLineFromCF {
    NSURLResponse *response = self;
    NSString *statusLine = @"";
    // 获取CFURLResponseGetHTTPResponse的函数实现
    // 注意：后期优化 私有API处理
    NSString *funName = @"CFURLResponseGetHTTPResponse";
    DMURLResponseGetHTTPResponse originURLResponseGetHTTPResponse =
    dlsym(RTLD_DEFAULT, [funName UTF8String]);

    SEL theSelector = NSSelectorFromString(@"_CFURLResponse");
    if ([response respondsToSelector:theSelector] &&
        NULL != originURLResponseGetHTTPResponse) {
        // 获取NSURLResponse的_CFURLResponse
        CFTypeRef cfResponse = CFBridgingRetain([response performSelector:theSelector]);
        if (NULL != cfResponse) {
            // 将CFURLResponseRef转化为CFHTTPMessageRef
            CFHTTPMessageRef messageRef = originURLResponseGetHTTPResponse(cfResponse);
            statusLine = (__bridge_transfer NSString *)CFHTTPMessageCopyResponseStatusLine(messageRef);
            CFRelease(cfResponse);
        }
    }
    if (statusLine.length>0) {
        statusLine = [statusLine stringByAppendingString:@"\r\n"];
    }
    return statusLine;
}

- (NSString *)ft_getResponseContentWithData:(NSData *)data{
    NSString *headerStr;
    if ([self isKindOfClass:[NSHTTPURLResponse class]]) {
         NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)self;
         NSDictionary<NSString *, NSString *> *headerFields = httpResponse.allHeaderFields;
         headerStr = [self ft_getStatusLineFromCF];
         for (NSString *key in headerFields.allKeys) {
             headerStr = [headerStr stringByAppendingString:key];
             headerStr = [headerStr stringByAppendingString:@": "];
             if ([headerFields objectForKey:key]) {
                 headerStr = [headerStr stringByAppendingString:headerFields[key]];
             }
             headerStr = [headerStr stringByAppendingString:@"\n"];
         }
     }
    NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
       if (dataStr) {
           headerStr = [headerStr stringByAppendingFormat:@"\n%@",dataStr];
       }
    return headerStr;
}
@end
