//
//  FTMonitorManager.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTMonitorManager.h"
#import <CoreLocation/CLLocationManager.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <resolv.h>
#include <dns.h>

@implementation FTMonitorManager

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
- (NSString *)wifiSSID {
    
    NSString *ssid = nil;
//    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
//    for (NSString *ifnam in ifs) {
//        NSDictionary *info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
//        if (info[@"SSID"]) {
//            ssid = info[@"SSID"];
//        }
//    }
    return ssid;
}
- (NSDictionary *)getDNSInfo {
    NSMutableDictionary *dnsDict = [NSMutableDictionary new];
    res_state res = malloc(sizeof(struct __res_state));
    int result = res_ninit(res);
    if (result == 0) {
        for (int i=0;i<res->nscount;i++) {
            NSString *s = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
            [dnsDict setValue:s forKey:[NSString stringWithFormat:@"DNS%d",i+1]];
        }
    }
    res_nclose(res);
    res_ndestroy(res);
    free(res);
    return dnsDict;
}


@end
