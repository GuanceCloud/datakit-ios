//
//  FTMonitorManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTMonitorManager.h"
#import <CoreLocation/CLLocationManager.h>
#import <CoreBluetooth/CoreBluetooth.h>
#include <arpa/inet.h>
#include <resolv.h>
#include <dns.h>
#import <ifaddrs.h>
 #import <SystemConfiguration/CaptiveNetwork.h>
@interface FTMonitorManager ()<CBCentralManagerDelegate>
@property (nonatomic, strong) CBCentralManager *centralManager;
@end
@implementation FTMonitorManager
-(instancetype)init{
    self = [super init];
       if (self) {
           [self startMonitor];
       }
    return self;
}
- (void)startMonitor{

}
//系统开机时间获取
- (double)getLaunchSystemTime{
    NSTimeInterval timer = [NSProcessInfo processInfo].systemUptime;
    NSDate *currentDate = [NSDate new];
    NSDate *startTime = [currentDate dateByAddingTimeInterval:(-timer)];
    NSTimeInterval convertStartTimeToSecond = [startTime timeIntervalSince1970];
    return convertStartTimeToSecond;
}
//用户自定义的手机名称
- (NSString *)userDeviceName{
    NSString * userPhoneName = [[UIDevice currentDevice] name];
    return userPhoneName;
}
//- (NSDictionary *)getDNSInfo {
//    NSMutableDictionary *dnsDict = [NSMutableDictionary new];
//    res_state res = malloc(sizeof(struct __res_state));
//    int result = res_ninit(res);
//    if (result == 0) {
//        for (int i=0;i<res->nscount;i++) {
//            NSString *s = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
//            [dnsDict setValue:s forKey:[NSString stringWithFormat:@"DNS%d",i+1]];
//        }
//    }
//    res_nclose(res);
//    res_ndestroy(res);
//    free(res);
//    return dnsDict;
//}
#pragma mark ========== 蓝牙 ==========
- (void)bluteeh{
    NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey:@NO};
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:options];
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *strMessage = nil;
    switch (central.state) {
        case CBManagerStatePoweredOn: {
            NSLog(@"蓝牙开启且可用");
            return;
        }
            break;
        case CBManagerStateUnknown: {
            strMessage = @"手机没有识别到蓝牙，请检查手机。";
        }
            break;
        case CBManagerStateResetting: {
            strMessage = @"手机蓝牙已断开连接，重置中...";
        }
            break;
        case CBManagerStateUnsupported: {
            strMessage = @"手机不支持蓝牙功能，请更换手机。";
        }
            break;
        case CBManagerStatePoweredOff: {
            strMessage = @"手机蓝牙功能关闭，请前往设置打开蓝牙及控制中心打开蓝牙。";
        }
            break;
        case CBManagerStateUnauthorized: {
            strMessage = @"手机蓝牙功能没有权限，请前往设置。";
        }
            break;
        default: { }
            break;
    }
    
}
#pragma mark ========== WIFI的SSID 与 IP ==========
/**
 * iOS 13 之后需要定位开启 才能获取到信息
 */
// 获取设备当前连接的WIFI的SSID
- (NSString *) getCurrentWifi{
    NSString * wifiName = @"";
    CFArrayRef wifiInterfaces = CNCopySupportedInterfaces();
    
    if (!wifiInterfaces) {
        wifiName = @"";
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
- (NSString *)getIPAddress {
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

@end
