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
            return @{@"wifi_ip": [self getIPAddress]};
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
    NSString *address = @"error";
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
@end
