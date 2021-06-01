//
//  FTNetworkInfo.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/1/14.
//  Copyright © 2020 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import <UIKit/UIKit.h>
#import "FTNetworkInfo.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

@implementation FTNetworkInfo
+ (NSString *)getNetworkType{
    NSArray *typeStrings2G = @[CTRadioAccessTechnologyEdge,
                               CTRadioAccessTechnologyGPRS,
                               CTRadioAccessTechnologyCDMA1x];
    NSArray *typeStrings3G = @[CTRadioAccessTechnologyHSDPA,
                               CTRadioAccessTechnologyWCDMA,
                               CTRadioAccessTechnologyHSUPA,
                               CTRadioAccessTechnologyCDMAEVDORev0,
                               CTRadioAccessTechnologyCDMAEVDORevA,
                               CTRadioAccessTechnologyCDMAEVDORevB,
                               CTRadioAccessTechnologyeHRPD];
    
    NSArray *typeStrings4G = @[CTRadioAccessTechnologyLTE];
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        CTTelephonyNetworkInfo *teleInfo= [[CTTelephonyNetworkInfo alloc] init];
        NSString *accessString = teleInfo.currentRadioAccessTechnology;
        if (@available(iOS 14.1, *)) {
            NSArray *typeStrings5G = @[CTRadioAccessTechnologyNRNSA,
                                       CTRadioAccessTechnologyNR];
            if ([typeStrings5G containsObject:accessString]) {
                return @"5G";
            }
        }
        if ([typeStrings4G containsObject:accessString]) {
            return @"4G";
        } else if ([typeStrings3G containsObject:accessString]) {
            return @"3G";
        } else if ([typeStrings2G containsObject:accessString]) {
            return @"2G";
        } else {
            return @"unknown";
        }
    } else {
        return @"unknown";
    }
}
@end
