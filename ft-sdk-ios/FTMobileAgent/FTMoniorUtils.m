//
//  FTMoniorUtils.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTMoniorUtils.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreLocation/CLLocationManager.h>
#import "ZYLog.h"
#include <arpa/inet.h>
#include <resolv.h>
#include <dns.h>
#import <ifaddrs.h>
#include <netdb.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <net/if.h>
#import <mach/mach.h>
#import <assert.h>
#import <AVFoundation/AVFoundation.h>
@implementation FTMoniorUtils
#pragma mark ========== 开机时间/自定义手机名称 ==========
//系统开机时间获取
+ (NSString *)getLaunchSystemTime{
    NSTimeInterval timer = [NSProcessInfo processInfo].systemUptime;
    NSDate *currentDate = [NSDate new];
    NSDate *startTime = [currentDate dateByAddingTimeInterval:(-timer)];
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *dateStr = [formatter stringFromDate:startTime];
    return dateStr;
}
//用户自定义的手机名称
+ (NSString *)userDeviceName{
    NSString * userPhoneName = [[UIDevice currentDevice] name];
    return userPhoneName;
}
#pragma mark ==========  dns ==========
+ (NSDictionary *)getDNSInfo{
    NSMutableDictionary *dnsDict = [NSMutableDictionary new];
    res_state res = malloc(sizeof(struct __res_state));
    int result = res_ninit(res);
    if (result == 0) {
        for (int i=0;i<res->nscount;i++) {
            NSString *s = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
            [dnsDict setValue:s forKey:[NSString stringWithFormat:@"dns%d",i+1]];
        }
    }
    res_nclose(res);
    res_ndestroy(res);
    free(res);
    return dnsDict;
}
#pragma mark ========== WIFI的SSID 与 IP ==========
/**
 * iOS 12 之后WifiSSID 需要配置 'capability' ->'Access WiFi Infomation' 才能获取 还需要配置证书
 * iOS 13 之后需要定位开启 才能获取到信息
 */
+ (NSDictionary *)getWifiAccessAndIPAddress{
    if (@available(iOS 13.0, *)) {
        if ([CLLocationManager locationServicesEnabled] && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways)) {
            return @{@"wifi_ssid": [self getCurrentWifiSSID],@"wifi_ip": [self getIPAddress]};
        }else if ([CLLocationManager authorizationStatus] ==kCLAuthorizationStatusDenied) {
            ZYDebug(@"用户拒绝授权或未开启定位服务");
            return @{@"wifi_ip": [self getIPAddress],@"wifi_ssid":@"N/A"};
        }
        return nil;
    }else{
        return @{@"wifi_ssid": [self getCurrentWifiSSID],@"wifi_ip": [self getIPAddress]};
    }
}
// 获取设备当前连接的WIFI的SSID  需要配置 Access WiFi Infomation
+ (NSString *)getCurrentWifiSSID{
    NSString * wifiName = @"N/A";
    CFArrayRef wifiInterfaces = CNCopySupportedInterfaces();
    if (!wifiInterfaces) {
        wifiName = @"N/A";
    }
    NSArray *interfaces = (__bridge NSArray *)wifiInterfaces;
    for (NSString *interfaceName in interfaces) {
        CFDictionaryRef dictRef = CNCopyCurrentNetworkInfo((__bridge CFStringRef)(interfaceName));
        if (dictRef) {
            NSDictionary *networkInfo = (__bridge NSDictionary *)dictRef;
            wifiName = [networkInfo objectForKey:(__bridge NSString *)kCNNetworkInfoKeySSID];
            CFRelease(dictRef);
        }
    }
    return wifiName;
}
// - 获取当前Wi-Fi的IP
+ (NSString *)getIPAddress{
    NSString *address = @"N/A";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}
+ (CGFloat)screenBrightness{
    return [UIScreen mainScreen].brightness;
}
+(BOOL)getProximityState{
    if ([UIDevice currentDevice].proximityMonitoringEnabled == NO) {
        [UIDevice currentDevice].proximityMonitoringEnabled = YES;
    }
    return [UIDevice currentDevice].proximityState;
}
+ (float)getTorchLevel{
   AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
      return device.torchLevel;
}
#pragma mark ========== 电池 ==========
//电池电量
+(double)ft_getBatteryUse{
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    double deviceLevel = [UIDevice currentDevice].batteryLevel;
    if (deviceLevel == -1) {
        return 0;
    }else{
    return deviceLevel*100;
    }
}
//电池是否在充电
+ (NSString *)ft_batteryStatus{
    switch ([UIDevice currentDevice].batteryState) {
        case UIDeviceBatteryStateUnknown:
            return @"unknown";
            break;
        case UIDeviceBatteryStateUnplugged:
            return @"unplugged";
            break;
        case UIDeviceBatteryStateCharging:
            return @"charging";
            break;
        case UIDeviceBatteryStateFull:
            return @"full";
            break;
    }
}
#pragma mark ========== 内存 ==========
//当前设备可用内存
+ (double)ft_availableMemory
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
+ (double)ft_usedMemory
{
    vm_statistics_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(),
                                               HOST_VM_INFO,
                                               (host_info_t)&vmStats,
                                               &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        return 0;
    }
    
    double availableMemory = ((vm_page_size * vmStats.free_count) / 1024.0) / 1024.0;
    double total = [NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0;
    double numFloat =(total-availableMemory)/total;
    return numFloat*100;
}
//总内存
+(NSString *)ft_getTotalMemorySize{
    return [NSString stringWithFormat:@"%.2fG",[NSProcessInfo processInfo].physicalMemory / 1024.0 / 1024.0/ 1024.0];
    
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
+ (NSString *)ft_getFrontCameraPixel{
    AVCaptureDevice *captureDevice = [self cameraWithPosition:AVCaptureDevicePositionFront];
    NSArray* availFormat=captureDevice.formats;
    AVCaptureDeviceFormat *format = [availFormat lastObject];
    CMVideoDimensions dis = format.highResolutionStillImageDimensions;
    return [NSString stringWithFormat:@"%d万像素",dis.width*dis.height/10000];
}
+ (NSString *)ft_getBackCameraPixel{
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
+ (BOOL)getRoamingStates{
    NSBundle *b = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/AppStoreDaemon.framework"];
    BOOL state = NO;
    if ([b load]) {
        Class ASDCellularIdentity = NSClassFromString(@"ASDCellularIdentity");
        id  asiden = [[ASDCellularIdentity alloc]init];
        id is = [asiden valueForKey:@"roaming"];
        state = [is boolValue];
    }
    return state;
}
@end
