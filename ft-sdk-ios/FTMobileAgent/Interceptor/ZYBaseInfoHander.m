//
//  ZYDeviceInfoHander.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYBaseInfoHander.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "ZYLog.h"
#import <mach/mach.h>
#import <assert.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <AVFoundation/AVFoundation.h>

#define setUUID(uuid) [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:@"FTSDKUUID"]
#define getUUID        [[NSUserDefaults standardUserDefaults] valueForKey:@"FTSDKUUID"]

@implementation ZYBaseInfoHander : NSObject
+ (NSString *)getDeviceType{
    struct utsname systemInfo;
     uname(&systemInfo);
     NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
     
     //------------------------------iPhone---------------------------
     if ([platform isEqualToString:@"iPhone1,1"]) return @"iPhone 2G";
     if ([platform isEqualToString:@"iPhone1,2"]) return @"iPhone 3G";
     if ([platform isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS";
     if ([platform isEqualToString:@"iPhone3,1"] ||
         [platform isEqualToString:@"iPhone3,2"] ||
         [platform isEqualToString:@"iPhone3,3"]) return @"iPhone 4";
     if ([platform isEqualToString:@"iPhone4,1"]) return @"iPhone 4S";
     if ([platform isEqualToString:@"iPhone5,1"] ||
         [platform isEqualToString:@"iPhone5,2"]) return @"iPhone 5";
     if ([platform isEqualToString:@"iPhone5,3"] ||
         [platform isEqualToString:@"iPhone5,4"]) return @"iPhone 5c";
     if ([platform isEqualToString:@"iPhone6,1"] ||
         [platform isEqualToString:@"iPhone6,2"]) return @"iPhone 5s";
     if ([platform isEqualToString:@"iPhone7,2"]) return @"iPhone 6";
     if ([platform isEqualToString:@"iPhone7,1"]) return @"iPhone 6 Plus";
     if ([platform isEqualToString:@"iPhone8,1"]) return @"iPhone 6s";
     if ([platform isEqualToString:@"iPhone8,2"]) return @"iPhone 6s Plus";
     if ([platform isEqualToString:@"iPhone8,4"]) return @"iPhone SE";
     if ([platform isEqualToString:@"iPhone9,1"] ||
         [platform isEqualToString:@"iPhone9,3"]) return @"iPhone 7";
     if ([platform isEqualToString:@"iPhone9,2"] ||
         [platform isEqualToString:@"iPhone9,4"]) return @"iPhone 7 Plus";
     if ([platform isEqualToString:@"iPhone10,1"] ||
         [platform isEqualToString:@"iPhone10,4"]) return @"iPhone 8";
     if ([platform isEqualToString:@"iPhone10,2"] ||
         [platform isEqualToString:@"iPhone10,5"]) return @"iPhone 8 Plus";
     if ([platform isEqualToString:@"iPhone10,3"] ||
         [platform isEqualToString:@"iPhone10,6"]) return @"iPhone X";
     if ([platform isEqualToString:@"iPhone11,8"]) return @"iPhone XR";
     if ([platform isEqualToString:@"iPhone11,2"]) return @"iPhone XS";
     if ([platform isEqualToString:@"iPhone11,4"] ||
         [platform isEqualToString:@"iPhone11,6"]) return @"iPhone XS Max";
     if ([platform isEqualToString:@"iPhone12,1"]) return @"iPhone 11";
     if ([platform isEqualToString:@"iPhone12,3"]) return @"iPhone 11 Pro";
     if ([platform isEqualToString:@"iPhone12,5"]) return @"iPhone 11 Pro Max";

     //------------------------------iPad--------------------------
     if ([platform isEqualToString:@"iPad1,1"]) return @"iPad";
     if ([platform isEqualToString:@"iPad2,1"] ||
         [platform isEqualToString:@"iPad2,2"] ||
         [platform isEqualToString:@"iPad2,3"] ||
         [platform isEqualToString:@"iPad2,4"]) return @"iPad 2";
     if ([platform isEqualToString:@"iPad3,1"] ||
         [platform isEqualToString:@"iPad3,2"] ||
         [platform isEqualToString:@"iPad3,3"]) return @"iPad 3";
     if ([platform isEqualToString:@"iPad3,4"] ||
         [platform isEqualToString:@"iPad3,5"] ||
         [platform isEqualToString:@"iPad3,6"]) return @"iPad 4";
     if ([platform isEqualToString:@"iPad4,1"] ||
         [platform isEqualToString:@"iPad4,2"] ||
         [platform isEqualToString:@"iPad4,3"]) return @"iPad Air";
     if ([platform isEqualToString:@"iPad5,3"] ||
         [platform isEqualToString:@"iPad5,4"]) return @"iPad Air 2";
     if ([platform isEqualToString:@"iPad6,3"] ||
         [platform isEqualToString:@"iPad6,4"]) return @"iPad Pro 9.7-inch";
     if ([platform isEqualToString:@"iPad6,7"] ||
         [platform isEqualToString:@"iPad6,8"]) return @"iPad Pro 12.9-inch";
     if ([platform isEqualToString:@"iPad6,11"] ||
         [platform isEqualToString:@"iPad6,12"]) return @"iPad 5";
     if ([platform isEqualToString:@"iPad7,11"] ||
         [platform isEqualToString:@"iPad7,12"]) return @"iPad 6";
     if ([platform isEqualToString:@"iPad7,1"] ||
         [platform isEqualToString:@"iPad7,2"]) return @"iPad Pro 12.9-inch 2";
     if ([platform isEqualToString:@"iPad7,3"] ||
         [platform isEqualToString:@"iPad7,4"]) return @"iPad Pro 10.5-inch";
     
     //------------------------------iPad Mini-----------------------
     if ([platform isEqualToString:@"iPad2,5"] ||
         [platform isEqualToString:@"iPad2,6"] ||
         [platform isEqualToString:@"iPad2,7"]) return @"iPad mini";
     if ([platform isEqualToString:@"iPad4,4"] ||
         [platform isEqualToString:@"iPad4,5"] ||
         [platform isEqualToString:@"iPad4,6"]) return @"iPad mini 2";
     if ([platform isEqualToString:@"iPad4,7"] ||
         [platform isEqualToString:@"iPad4,8"] ||
         [platform isEqualToString:@"iPad4,9"]) return @"iPad mini 3";
     if ([platform isEqualToString:@"iPad5,1"] ||
         [platform isEqualToString:@"iPad5,2"]) return @"iPad mini 4";
     
     //------------------------------iTouch------------------------
     if ([platform isEqualToString:@"iPod1,1"]) return @"iTouch";
     if ([platform isEqualToString:@"iPod2,1"]) return @"iTouch2";
     if ([platform isEqualToString:@"iPod3,1"]) return @"iTouch3";
     if ([platform isEqualToString:@"iPod4,1"]) return @"iTouch4";
     if ([platform isEqualToString:@"iPod5,1"]) return @"iTouch5";
     if ([platform isEqualToString:@"iPod7,1"]) return @"iTouch6";
     
     //------------------------------Samulitor-------------------------------------
     if ([platform isEqualToString:@"i386"] ||
         [platform isEqualToString:@"x86_64"]) return @"iPhone Simulator";
     
     return platform;
}
+(NSString *)getTelephonyInfo     // 获取运营商信息
{
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier;
    if (@available(iOS 12.0, *)) {
       if (info && [info respondsToSelector:@selector(serviceSubscriberCellularProviders)]) {
                NSDictionary *dic = [info serviceSubscriberCellularProviders];
                if (dic.allKeys.count) {
                    carrier = [dic objectForKey:dic.allKeys[0]];
                }
              }
    }else{
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // 这部分使用到的过期api
        carrier= [info subscriberCellularProvider];
        #pragma clang diagnostic pop
        
    }
    NSString *mCarrier = [NSString stringWithFormat:@"%@",[carrier carrierName]];
    return mCarrier;
}
+ (NSString *)resolution {
    CGRect rect = [[UIScreen mainScreen] bounds];
    CGFloat scale = [[UIScreen mainScreen] scale];
    return [[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height*scale,rect.size.width*scale];
}
+(NSString *)convertToJsonData:(NSDictionary *)dict
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString;
    if (!jsonData) {
        ZYDebug(@"ERROR == %@",error);
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];

    NSRange range = {0,jsonString.length};

    //去掉字符串中的空格
    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];
    NSRange range2 = {0,mutStr.length};
    //去掉字符串中的换行符
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];

    return mutStr;

}
+ (long)getCurrentTimestamp{
    
    NSDate *datenow = [NSDate date];//现在时间,你可以输出来看下是什么格式
    long time= (long)([datenow timeIntervalSince1970]*1000*1000);
    return  time;
    
}

+ (NSString *)md5EncryptStr:(NSString *)str {
     const char *input = [str UTF8String];//UTF8转码
     unsigned char result[CC_MD5_DIGEST_LENGTH];
     CC_MD5(input, (CC_LONG)strlen(input), result);
     NSData *data = [NSData dataWithBytes: result length:16];
     NSString *string = [data base64EncodedStringWithOptions:0];//base64编码;
     return string;
}
+(NSString*)getSSOSignWithAkSecret:(NSString *)akSecret datetime:(NSString *)datetime data:(NSString *)data
{
    NSMutableString *signString = [[NSMutableString alloc] init];
    
    [signString appendString:@"POST"];
    [signString appendString:@"\n"];
    [signString appendString:[self md5EncryptStr:data]];
    [signString appendString:@"\n"];
    [signString appendString:@"text/plain"];
    [signString appendString:@"\n"];
    [signString appendString:[NSString stringWithFormat:@"%@",datetime]];
    const char *secretStr = [akSecret UTF8String];
    const char * signStr = [signString UTF8String];
    
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, secretStr, strlen(secretStr), signStr, strlen(signStr), cHMAC);
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:CC_SHA1_DIGEST_LENGTH];
    return [HMAC base64EncodedStringWithOptions:0];
}
+ (NSString *)currentGMT {
    
    NSDate *date = [NSDate date];
    
    NSTimeZone *tzGMT = [NSTimeZone timeZoneWithName:@"GMT"];
    
    [NSTimeZone setDefaultTimeZone:tzGMT];
    
    NSDateFormatter *iosDateFormater=[[NSDateFormatter alloc]init];
    
    iosDateFormater.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
    
    iosDateFormater.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US"];
    
    return [iosDateFormater stringFromDate:date];
}
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }

    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        ZYDebug(@"json解析失败：%@",err); 
        return nil;
    }
    return dic;
}
// UUID
+ (NSString *)defaultUUID {
    NSString *deviceId;
    deviceId =getUUID;
    if (!deviceId) {
        deviceId = [[NSUUID UUID] UUIDString];
        setUUID(deviceId);
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return deviceId;
}
#pragma mark ========== cpu ==========
+ (long )ft_cpuUsage{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;

    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }

    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;

    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;

    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads

    basic_info = (task_basic_info_t)tinfo;

    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;

    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;

    for (j = 0; j < (int)thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }

        basic_info_th = (thread_basic_info_t)thinfo;

        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }

    } // for each thread

    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);

    return tot_cpu;
}
+ (NSString *)ft_getCPUType{
    host_basic_info_data_t hostInfo;
    mach_msg_type_number_t infoCount;
    
    infoCount = HOST_BASIC_INFO_COUNT;
    host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount);
    
    switch (hostInfo.cpu_type) {
        case CPU_TYPE_ARM:
            return @"CPU_TYPE_ARM";
            break;
            
        case CPU_TYPE_ARM64:
            return @"CPU_TYPE_ARM64";
            break;
            
        case CPU_TYPE_X86:
            return @"CPU_TYPE_X86";
            break;
            
        case CPU_TYPE_X86_64:
            return @"CPU_TYPE_X86_64";
            break;
        default:
            break;
    }
    return @"";
}
#pragma mark ========== 电池 ==========
//电池电量
+(NSString *)ft_getBatteryUse{
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    double deviceLevel = [UIDevice currentDevice].batteryLevel;
    return [NSString stringWithFormat:@"%.f%%",(1-deviceLevel)*100];
}
-(NSString *) getBatteryState {
    UIDevice *device = [UIDevice currentDevice];
    if (device.batteryState == UIDeviceBatteryStateUnknown) {
        return @"UnKnow";
    }else if (device.batteryState == UIDeviceBatteryStateUnplugged){
        return @"Unplugged";
    }else if (device.batteryState == UIDeviceBatteryStateCharging){
        return @"Charging";
    }else if (device.batteryState == UIDeviceBatteryStateFull){
        return @"Full";
    }
    return nil;
}
#pragma mark ========== 内存 ==========
//当前设备可用内存
+ (double)availableMemory
{
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(),
                                               HOST_VM_INFO,
                                               (host_info_t)&vmStats,
                                               &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        return NSNotFound;
    }
    
    return ((vm_page_size * vmStats.free_count) / 1024.0) / 1024.0;
}
//当前任务所占用的内存
+ (NSString *)usedMemory
{
    vm_statistics_data_t vmStats;
       mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
       kern_return_t kernReturn = host_statistics(mach_host_self(),
                                                  HOST_VM_INFO,
                                                  (host_info_t)&vmStats,
                                                  &infoCount);
       
       if (kernReturn != KERN_SUCCESS) {
           return @"0";
       }
       
    double availableMemory = ((vm_page_size * vmStats.free_count) / 1024.0) / 1024.0;
    double total = [NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0;
    
    return [NSString stringWithFormat:@"%.2f%%",(total-availableMemory)/total*1.00*100];
}
//总内存
+(long long)getTotalMemorySize{
    return [NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0;

}
+ (NSString *)gt_getFrontCameraPixel{
      AVCaptureDevice *captureDevice = [self cameraWithPosition:AVCaptureDevicePositionFront];
      NSArray* availFormat=captureDevice.formats;
      AVCaptureDeviceFormat *format = [availFormat lastObject];
      CMVideoDimensions dis = format.highResolutionStillImageDimensions;
      return [NSString stringWithFormat:@"%d万像素",dis.width*dis.height/10000];
}
+ (NSString *)gt_getBackCameraPixel{
    AVCaptureDevice *captureDevice = [self cameraWithPosition:AVCaptureDevicePositionBack];
    NSArray* availFormat=captureDevice.formats;
    AVCaptureDeviceFormat *format = [availFormat lastObject];
    CMVideoDimensions dis = format.highResolutionStillImageDimensions;
    return [NSString stringWithFormat:@"%d万像素",dis.width*dis.height/10000];
}

+ (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position
{
     NSArray *devices;
    if (@available(iOS 10.0, *)) {
        AVCaptureDeviceDiscoverySession *devicesIOS10 = [AVCaptureDeviceDiscoverySession  discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
        devices  = devicesIOS10.devices;
    } else {
        devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];    }

    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

@end
