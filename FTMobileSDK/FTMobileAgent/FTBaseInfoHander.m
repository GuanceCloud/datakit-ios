//
//  FTBaseInfoHander.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTBaseInfoHander.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "FTLog.h"
#import "FTConstants.h"
#import "FTTrackBean.h"
#import "NSString+FTAdd.h"
#import "FTJSONUtil.h"
@implementation FTBaseInfoHander : NSObject

#pragma mark ========== 请求加密 ==========
+(NSString*)ft_getSignatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data
{
    NSMutableString *signString = [[NSMutableString alloc] init];
    [signString appendString:method];
    [signString appendString:@"\n"];
    [signString appendString:[data ft_md5base64Encrypt]];
    [signString appendString:@"\n"];
    [signString appendString:contentType];
    [signString appendString:@"\n"];
    [signString appendString:dateStr];
    const char *secretStr = [akSecret UTF8String];
    const char * signStr = [signString UTF8String];
    
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, secretStr, strlen(secretStr), signStr, strlen(signStr), cHMAC);
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:CC_SHA1_DIGEST_LENGTH];
    return [HMAC base64EncodedStringWithOptions:0];
}
#pragma mark ========== 字符串处理  前后空格移除、特殊字符转换、校验合法 ==========
+ (id)repleacingSpecialCharacters:(id )str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
        reStr =[reStr stringByReplacingOccurrencesOfString:@"=" withString:@"\\="];
        reStr =[reStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        return reStr;
    }else{
        return str;
    }
    
}
+ (id)repleacingSpecialCharactersField:(id )str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        return reStr;
    }else{
        return str;
    }
    
}
+ (id)repleacingSpecialCharactersMeasurement:(id )str{
    if ([str isKindOfClass:NSString.class]) {
        NSString *reStr = [str stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
        reStr =[reStr stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
        return reStr;
    }else{
        return str;
    }
    
}

+(NSString *)ft_getFTstatueStr:(FTStatus)status{
    NSString *str = nil;
    switch (status) {
        case FTStatusInfo:
            str = @"info";
            break;
        case FTStatusWarning:
            str = @"warning";
            break;
        case FTStatusError:
            str = @"error";
            break;
        case FTStatusCritical:
            str = @"critical";
            break;
        case FTStatusOk:
            str = @"ok";
            break;
    }
    return str;
}

+(NSString *)ft_getNetworkTraceID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [uuid lowercaseString];
}
+(NSString *)ft_getNetworkSpanID{
    NSString *uuid = [NSUUID UUID].UUIDString;
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    return [[uuid lowercaseString] ft_md5HashToLower16Bit];
}
+ (void)performBlockDispatchMainSyncSafe:(DISPATCH_NOESCAPE dispatch_block_t)block{
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
+ (NSString *)ft_getCurrentPageName{
    __block UIViewController *result = nil;
    __block UIWindow * window;
    [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
        
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes)
            {
                if (windowScene.activationState == UISceneActivationStateForegroundActive)
                {
                    window = windowScene.windows.firstObject;
                    break;
                }
            }
        }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // 这部分使用到的过期api
            window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        }
        if (window.windowLevel != UIWindowLevelNormal)
        {
            NSArray *windows = [[UIApplication sharedApplication] windows];
            for(UIWindow * tmpWin in windows)
            {
                if (tmpWin.windowLevel == UIWindowLevelNormal)
                {
                    window = tmpWin;
                    break;
                }
            }
        }
        
        UIView *frontView = [[window subviews] objectAtIndex:0];
        id nextResponder = [frontView nextResponder];
        
        if ([nextResponder isKindOfClass:[UIViewController class]])
            result = nextResponder;
        else
            result = window.rootViewController;
        
        if ([result isKindOfClass:[UITabBarController class]]) {
            
            UIViewController  *tabSelectVC = ((UITabBarController*)result).selectedViewController;
            
            if ([tabSelectVC isKindOfClass:[UINavigationController class]]) {
                
              result=((UINavigationController*)tabSelectVC).viewControllers.lastObject ;
            }else{
                result=  tabSelectVC;
            }
        }else
            if ([result isKindOfClass:[UINavigationController class]]) {
                result = ((UINavigationController*)result).viewControllers.lastObject;
            }
    }];
    if (result) {
        return  NSStringFromClass(result.class);
    }
    return FT_NULL_VALUE;
}
@end
