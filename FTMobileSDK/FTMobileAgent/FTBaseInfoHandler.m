//
//  FTBaseInfoHandler.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTBaseInfoHandler.h"
#import <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "NSString+FTAdd.h"
#include <mach-o/dyld.h>
#include <netdb.h>
#include <arpa/inet.h>
@implementation FTBaseInfoHandler : NSObject

#pragma mark ========== 请求加密 ==========
+(NSString*)signatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data
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

+ (NSString *)applicationUUID{
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
+ (UIWindow *)keyWindow{
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
+ (NSString *)XDataKitUUID{
    NSString *deviceId;
    deviceId = [[NSUserDefaults standardUserDefaults] valueForKey:@"FTSDKUUID"];
    if (!deviceId) {
        deviceId = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setValue:deviceId forKey:@"FTSDKUUID"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return deviceId;
}
+ (NSString *)sessionId{
    NSString  *sessionid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_sessionid"];
    if (!sessionid) {
        sessionid = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setValue:sessionid forKey:@"ft_sessionid"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return sessionid;
}
+ (NSString *)userId{
    NSString  *sessionid =[[NSUserDefaults standardUserDefaults] valueForKey:@"ft_userid"];
    return sessionid;
}
+ (void)setUserId:(NSString *)userid{
        [[NSUserDefaults standardUserDefaults] setValue:userid forKey:@"ft_userid"];
        [[NSUserDefaults standardUserDefaults] synchronize];
}
+ (NSString *)convertToStringData:(NSDictionary *)dict{
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

+ (NSString *)replaceNumberCharByUrl:(NSURL *)url{
    NSString *relativePath = [url path];
    if (relativePath.length==0 || !relativePath) {
           return @"";
       }
       NSError *error = nil;
       NSString *pattern = @"\\/([^\\/]*)\\d([^\\/]*)";
       NSRegularExpression *regularExpress = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
       NSString *string = [regularExpress stringByReplacingMatchesInString:relativePath options:0 range:NSMakeRange(0, [relativePath length]) withTemplate:@"/?"];
       
       return string;
}

+ (NSString *)boolStr:(BOOL)isTrue{
    return isTrue?@"true":@"false";
}
+ (BOOL)randomSampling:(int)sampling{
    if(sampling<=0){
        return NO;
    }
    if(sampling<100){
        int x = arc4random() % 100;
        return x <= sampling ? YES:NO;
    }
    return YES;
}
@end
