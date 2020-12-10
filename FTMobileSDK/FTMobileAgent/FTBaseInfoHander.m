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
#import <sys/utsname.h>
#import <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "FTLog.h"
#import "FTConstants.h"
#import "NSString+FTAdd.h"
#import "FTJSONUtil.h"
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
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
    [FTBaseInfoHander performBlockDispatchMainSyncSafe:^{
        
        UIWindow * window = [FTBaseInfoHander ft_keyWindow];
        
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
+ (NSString *)ft_getApplicationUUID{
    // 获取 image 的 index
    const uint32_t imageCount = _dyld_image_count();
    
    uint32_t mainImg = 0;
    NSString *path =getExecutablePath();
    for(uint32_t iImg = 0; iImg < imageCount; iImg++) {
        const char* name = _dyld_get_image_name(iImg);
        NSString *imagePath = [NSString stringWithUTF8String:name];
        if ([imagePath isEqualToString:path]){
            mainImg = iImg;
            // 根据 index 获取 header
            const struct mach_header* header = _dyld_get_image_header(mainImg);
            uintptr_t cmdPtr = firstCmdAfterHeader(header);
            if(cmdPtr == 0) {
                return @"NULL";
            }
            
            uint8_t* uuid = NULL;
            
            for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++)
            {
                struct load_command* loadCmd = (struct load_command*)cmdPtr;
                
                if (loadCmd->cmd == LC_UUID) {
                    struct uuid_command* uuidCmd = (struct uuid_command*)cmdPtr;
                    uuid = uuidCmd->uuid;
                    break;
                }
                cmdPtr += loadCmd->cmdsize;
            }
            const char* result = nil;
            if(uuid != NULL)
            {
                result = uuidBytesToString(uuid);
                NSString *lduuid = [NSString stringWithUTF8String:result];
                return lduuid;
            }
        }
    }
    
    return @"NULL";
}
static NSString* getExecutablePath()
{
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSDictionary* infoDict = [mainBundle infoDictionary];
    NSString* bundlePath = [mainBundle bundlePath];
    NSString* executableName = infoDict[@"CFBundleExecutable"];
    return [bundlePath stringByAppendingPathComponent:executableName];
}
static const char* uuidBytesToString(const uint8_t* uuidBytes) {
    CFUUIDRef uuidRef = CFUUIDCreateFromUUIDBytes(NULL, *((CFUUIDBytes*)uuidBytes));
    NSString* str = (__bridge_transfer NSString*)CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    
    return cString(str);
}
const char* cString(NSString* str) {
    return str == NULL ? NULL : strdup(str.UTF8String);
}
//// 获取 Load Command
static uintptr_t firstCmdAfterHeader(const struct mach_header* const header) {
    switch(header->magic)
    {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            // Header is corrupt
            return 0;
    }
}
+ (UIWindow *)ft_keyWindow{
    UIWindow  *foundWindow = nil;
    NSArray   *windows = [[UIApplication sharedApplication]windows];
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) {
            foundWindow = window;
            break;
        }
    }
    return foundWindow;
}
+ (NSString *)itemHeatMapPathForResponder:(UIResponder *)responder {
    NSString *classString = NSStringFromClass(responder.class);

    NSArray *subResponder = nil;
    if ([responder isKindOfClass:UIView.class]) {
        UIResponder *next = [responder nextResponder];
        if ([next isKindOfClass:UIView.class]) {
            subResponder = [(UIView *)next subviews];
        }
    } else if ([responder isKindOfClass:UIViewController.class]) {
        subResponder = [(UIViewController *)responder parentViewController].childViewControllers;
    }

    NSInteger count = 0;
    NSInteger index = -1;
    for (UIResponder *res in subResponder) {
        if ([classString isEqualToString:NSStringFromClass(res.class)]) {
            count++;
        }
        if (res == responder) {
            index = count - 1;
        }
    }
    return count <= 1 ? classString : [NSString stringWithFormat:@"%@[%ld]", classString, (long)index];
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
+ (NSString *)ft_getFTEnvStr:(FTEnv)env{
   NSString *str = nil;
    switch (env) {
        case FTEnvProd:
            str = @"prod";
            break;
        case FTEnvGray:
            str = @"gray";
            break;
        case FTEnvPre:
            str = @"pre";
            break;
        case FTEnvCommon:
            str = @"common";
            break;
        case FTEnvLocal:
            str = @"local";
            break;
    }
   return str;
}
+ (NSString *)ft_getSessionid{
    NSString  *sessionid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_sessionid"];
    if (!sessionid) {
        sessionid = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setValue:sessionid forKey:@"ft_sessionid"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return sessionid;
}
+ (NSString *)ft_getUserid{
    NSString  *sessionid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_userid"];
    return sessionid;
}
+ (void)ft_setUserid:(NSString *)userid{
        [[NSUserDefaults standardUserDefaults] setValue:userid forKey:@"ft_userid"];
        [[NSUserDefaults standardUserDefaults] synchronize];
}
+ (NSString *)ft_getDictStr:(NSDictionary *)dict{
    __block NSString *str = @"";
    if (dict) {
        [dict.allKeys enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx == dict.allKeys.count) {
                str = [str stringByAppendingFormat:@"%@:%@",obj,dict[obj]];
            }else{
                str = [str stringByAppendingFormat:@"%@:%@\n",obj,dict[obj]];
            }
        }];
    }
    return str;
}
@end
