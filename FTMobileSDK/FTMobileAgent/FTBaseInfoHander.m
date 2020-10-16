//
//  FTBaseInfoHander.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTBaseInfoHander.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "FTLog.h"
#import <mach/mach.h>
#import <assert.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <AVFoundation/AVFoundation.h>
#import "FTConstants.h"
#import "FTTrackBean.h"
#import "NSString+FTAdd.h"
@implementation FTBaseInfoHander : NSObject
#pragma mark ========== 设备信息 ==========
+ (NSDictionary *)ft_getDeviceInfo{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
    
    //------------------------------iPhone---------------------------
    if ([platform isEqualToString:@"iPhone1,1"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 2G",
                 FTBaseInfoHanderDeviceCPUType:@"ARM1176JZ(F)-S v1.0",
                 FTBaseInfoHanderDeviceCPUClock:@"412MHz",
                 FTBaseInfoHanderBatteryTotal:@"1280mA",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR MBX Lite",
        };
    }
    if ([platform isEqualToString:@"iPhone1,2"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 3G",
                 FTBaseInfoHanderDeviceCPUType:@"ARM1176JZ(F)-S v1.0",
                 FTBaseInfoHanderDeviceCPUClock:@"412MHz",
                 FTBaseInfoHanderBatteryTotal:@"1280mA",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR MBX Lite",
        };
    }
    if ([platform isEqualToString:@"iPhone2,1"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 3GS",
                 FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A8",
                 FTBaseInfoHanderDeviceCPUClock:@"600MHz",
                 FTBaseInfoHanderBatteryTotal:@"1280mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX535",
        };
    }
    if ([platform isEqualToString:@"iPhone3,1"] ||
        [platform isEqualToString:@"iPhone3,2"] ||
        [platform isEqualToString:@"iPhone3,3"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 4",
                 FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A8",
                 FTBaseInfoHanderDeviceCPUClock:@"800MHz",
                 FTBaseInfoHanderBatteryTotal:@"1420mAH",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX535",
        };
    }
    if ([platform isEqualToString:@"iPhone4,1"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 4S",
                 FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A9",
                 FTBaseInfoHanderDeviceCPUClock:@"800MHz",
                 FTBaseInfoHanderBatteryTotal:@"1420mAH",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX543MP2",
        };
        
    }
    if ([platform isEqualToString:@"iPhone5,1"] ||
        [platform isEqualToString:@"iPhone5,2"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 5",
                 FTBaseInfoHanderDeviceCPUType:@"Swift",
                 FTBaseInfoHanderDeviceCPUClock:@"1300MHz",
                 FTBaseInfoHanderBatteryTotal:@"1440mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX543MP3",
        };
        
    }
    if ([platform isEqualToString:@"iPhone5,3"] ||
        [platform isEqualToString:@"iPhone5,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 5c",
                 FTBaseInfoHanderDeviceCPUType:@"Swift",
                 FTBaseInfoHanderDeviceCPUClock:@"1300MHz",
                 FTBaseInfoHanderBatteryTotal:@"1510mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX543MP3",
        };
    }
    if ([platform isEqualToString:@"iPhone6,1"] ||
        [platform isEqualToString:@"iPhone6,2"] ||
        [platform isEqualToString:@"iPhone6,3"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 5s",
                 FTBaseInfoHanderDeviceCPUType:@"Cyclone",
                 FTBaseInfoHanderDeviceCPUClock:@"1300MHz",
                 FTBaseInfoHanderBatteryTotal:@"1560mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR G6430",
        };
    }
    if ([platform isEqualToString:@"iPhone7,2"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 6",
                 FTBaseInfoHanderDeviceCPUType:@"Typhoon",
                 FTBaseInfoHanderDeviceCPUClock:@"1400MHz",
                 FTBaseInfoHanderBatteryTotal:@"1810mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GX6450",
        };
    }
    if ([platform isEqualToString:@"iPhone7,1"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 6 Plus",
                 FTBaseInfoHanderDeviceCPUType:@"Typhoon",
                 FTBaseInfoHanderDeviceCPUClock:@"1400MHz",
                 FTBaseInfoHanderBatteryTotal:@"2915mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GX6450",
        };
    }
    if ([platform isEqualToString:@"iPhone8,1"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 6s",
                 FTBaseInfoHanderDeviceCPUType:@"Twister",
                 FTBaseInfoHanderDeviceCPUClock:@"1850MHz",
                 FTBaseInfoHanderBatteryTotal:@"1715mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600",
        };
    }
    if ([platform isEqualToString:@"iPhone8,2"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 6s Plus",
                 FTBaseInfoHanderDeviceCPUType:@"Twister",
                 FTBaseInfoHanderDeviceCPUClock:@"1850MHz",
                 FTBaseInfoHanderBatteryTotal:@"2750mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600",
        };
    }
    if ([platform isEqualToString:@"iPhone8,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone SE",
                 FTBaseInfoHanderDeviceCPUType:@"Twister",
                 FTBaseInfoHanderDeviceCPUClock:@"1850MHz",
                 FTBaseInfoHanderBatteryTotal:@"1642mah",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600",
        };
    }
    if ([platform isEqualToString:@"iPhone9,1"] ||
        [platform isEqualToString:@"iPhone9,3"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 7",
                 FTBaseInfoHanderDeviceCPUType:@"Hurricane (x2) + Zephyr (x2)",
                 FTBaseInfoHanderDeviceCPUClock:@"2340MHz",
                 FTBaseInfoHanderBatteryTotal:@"1960mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600 Plus",
        };
    }
    if ([platform isEqualToString:@"iPhone9,2"] ||
        [platform isEqualToString:@"iPhone9,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 7 Plus",
                 FTBaseInfoHanderDeviceCPUType:@"Hurricane (x2) + Zephyr (x2)",
                 FTBaseInfoHanderDeviceCPUClock:@"2340MHz",
                 FTBaseInfoHanderBatteryTotal:@"2900mAh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600 Plus",
        };
    }
    if ([platform isEqualToString:@"iPhone10,1"] ||
        [platform isEqualToString:@"iPhone10,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 8",
                 FTBaseInfoHanderDeviceCPUType:@"Monsoon (x2) + Mistral (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2390MHz",
                 FTBaseInfoHanderBatteryTotal:@"1821mah",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone10,2"] ||
        [platform isEqualToString:@"iPhone10,5"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 8 Plus",
                 FTBaseInfoHanderDeviceCPUType:@"Monsoon (x2) + Mistral (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2390MHz",
                 FTBaseInfoHanderBatteryTotal:@"2675mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone10,3"] ||
        [platform isEqualToString:@"iPhone10,6"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone X",
                 FTBaseInfoHanderDeviceCPUType:@"Monsoon (x2) + Mistral (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2390MHz",
                 FTBaseInfoHanderBatteryTotal:@"2716mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone11,8"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone XR",
                 FTBaseInfoHanderDeviceCPUType:@"Vortex (x2) + Tempest (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2490MHz",
                 FTBaseInfoHanderBatteryTotal:@"2942mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone11,2"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone XS",
                 FTBaseInfoHanderDeviceCPUType:@"Vortex (x2) + Tempest (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2490MHz",
                 FTBaseInfoHanderBatteryTotal:@"2658mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone11,4"] ||
        [platform isEqualToString:@"iPhone11,6"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone XS Max",
                 FTBaseInfoHanderDeviceCPUType:@"Vortex (x2) + Tempest (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2490MHz",
                 FTBaseInfoHanderBatteryTotal:@"3174mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone12,1"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 11",
                 FTBaseInfoHanderDeviceCPUType:@"Lightning (×2) + Thunder (×4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2650MHz",
                 FTBaseInfoHanderBatteryTotal:@"3110mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone12,3"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 11 Pro",
                 FTBaseInfoHanderDeviceCPUType:@"Lightning (×2) + Thunder (×4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2650MHz",
                 FTBaseInfoHanderBatteryTotal:@"3190mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPhone12,5"]){
        return @{FTBaseInfoHanderDeviceType:@"iPhone 11 Pro Max",
                 FTBaseInfoHanderDeviceCPUType:@"Lightning (×2) + Thunder (×4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2650MHz",
                 FTBaseInfoHanderBatteryTotal:@"3500mAh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    
    //------------------------------iPad--------------------------
    if ([platform isEqualToString:@"iPad1,1"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad",
                 FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A8",
                 FTBaseInfoHanderDeviceCPUClock:@"1000MHz",
                 FTBaseInfoHanderBatteryTotal:@"25Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX535",
        };
    }
    if ([platform isEqualToString:@"iPad2,1"] ||
        [platform isEqualToString:@"iPad2,2"] ||
        [platform isEqualToString:@"iPad2,3"] ||
        [platform isEqualToString:@"iPad2,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad 2",
                 FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A9",
                 FTBaseInfoHanderDeviceCPUClock:@"1000MHz",
                 FTBaseInfoHanderBatteryTotal:@"25Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX543MP2",
        };
    }
    if ([platform isEqualToString:@"iPad3,1"] ||
        [platform isEqualToString:@"iPad3,2"] ||
        [platform isEqualToString:@"iPad3,3"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad 3",
                 FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A9",
                 FTBaseInfoHanderDeviceCPUClock:@"1000MHz",
                 FTBaseInfoHanderBatteryTotal:@"42.5Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX543MP4",
        };
    }
    if ([platform isEqualToString:@"iPad3,4"] ||
        [platform isEqualToString:@"iPad3,5"] ||
        [platform isEqualToString:@"iPad3,6"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad 4",
                 FTBaseInfoHanderDeviceCPUType:@"Swift",
                 FTBaseInfoHanderDeviceCPUClock:@"1400MHz",
                 FTBaseInfoHanderBatteryTotal:@"42.5Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX554MP4",
        };
    }
    if ([platform isEqualToString:@"iPad4,1"] ||
        [platform isEqualToString:@"iPad4,2"] ||
        [platform isEqualToString:@"iPad4,3"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Air",
                 FTBaseInfoHanderDeviceCPUType:@"Cyclone",
                 FTBaseInfoHanderDeviceCPUClock:@"1400MHz",
                 FTBaseInfoHanderBatteryTotal:@"30.2Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR G6430",
        };
    }
    if ([platform isEqualToString:@"iPad5,3"] ||
        [platform isEqualToString:@"iPad5,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Air 2",
                 FTBaseInfoHanderDeviceCPUType:@"Typhoon",
                 FTBaseInfoHanderDeviceCPUClock:@"1500MHz",
                 FTBaseInfoHanderBatteryTotal:@"27.3Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GXA6850",
        };
    }
    if ([platform isEqualToString:@"iPad6,3"] ||
        [platform isEqualToString:@"iPad6,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Pro 9.7-inch",
                 FTBaseInfoHanderDeviceCPUType:@"Twister",
                 FTBaseInfoHanderDeviceCPUClock:@"2260MHz",
                 FTBaseInfoHanderBatteryTotal:@"27.5Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GTA7850",
        };
    }
    if ([platform isEqualToString:@"iPad6,7"] ||
        [platform isEqualToString:@"iPad6,8"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Pro 12.9-inch",
                 FTBaseInfoHanderDeviceCPUType:@"Twister",
                 FTBaseInfoHanderDeviceCPUClock:@"2260MHz",
                 FTBaseInfoHanderBatteryTotal:@"38.5Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GTA7850",
        };
    }
    if ([platform isEqualToString:@"iPad6,11"] ||
        [platform isEqualToString:@"iPad6,12"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad 5",
                 FTBaseInfoHanderDeviceCPUType:@"Twister",
                 FTBaseInfoHanderDeviceCPUClock:@"1850MHz",
                 FTBaseInfoHanderBatteryTotal:@"32.4Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600",
        };
    }
    if ([platform isEqualToString:@"iPad7,5"] ||
        [platform isEqualToString:@"iPad7,6"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad 6",
                 FTBaseInfoHanderDeviceCPUType:@"Hurricane (x2) + Zephyr (x2)",
                 FTBaseInfoHanderDeviceCPUClock:@"2340MHz",
                 FTBaseInfoHanderBatteryTotal:@"32.4Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600 Plus",
        };
    }
    if ([platform isEqualToString:@"iPad7,11"] ||
        [platform isEqualToString:@"iPad7,12"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad 7",
                 FTBaseInfoHanderDeviceCPUType:@"Hurricane (x2) + Zephyr (x2)",
                 FTBaseInfoHanderDeviceCPUClock:@"2340MHz",
                 FTBaseInfoHanderBatteryTotal:@"32.4Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600 Plus",
        };
    }
    if ([platform isEqualToString:@"iPad7,1"] ||
        [platform isEqualToString:@"iPad7,2"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Pro 12.9-inch 2",
                 FTBaseInfoHanderDeviceCPUType:@"Hurricane (x3) + Zephyr (×3)",
                 FTBaseInfoHanderDeviceCPUClock:@"2360MHz",
                 FTBaseInfoHanderBatteryTotal:@"41Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600",
        };
    }
    if ([platform isEqualToString:@"iPad7,3"] ||
        [platform isEqualToString:@"iPad7,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Pro 10.5-inch",
                 FTBaseInfoHanderDeviceCPUType:@"Hurricane (x3) + Zephyr (×3)",
                 FTBaseInfoHanderDeviceCPUClock:@"2360MHz",
                 FTBaseInfoHanderBatteryTotal:@"30.4Wh",
                 FTBaseInfoHanderDeviceGPUType:@"PowerVR GT7600",
        };
    }
    if ([platform isEqualToString:@"iPad8,5"] ||
        [platform isEqualToString:@"iPad8,6"] ||
        [platform isEqualToString:@"iPad8,7"] ||
        [platform isEqualToString:@"iPad8,8"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Pro 12.9-inch 3",
                 FTBaseInfoHanderDeviceCPUType:@"Vortex (x4) + Tempest (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2490MHz",
                 FTBaseInfoHanderBatteryTotal:@"36.71Wh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPad8,1"] ||
        [platform isEqualToString:@"iPad8,2"] ||
        [platform isEqualToString:@"iPad8,3"] ||
        [platform isEqualToString:@"iPad8,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Pro 11.0-inch",
                 FTBaseInfoHanderDeviceCPUType:@"Vortex (x4) + Tempest (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2490MHz",
                 FTBaseInfoHanderBatteryTotal:@"29.37Wh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    if ([platform isEqualToString:@"iPad11,3"] ||
        [platform isEqualToString:@"iPad11,4"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad Air 3",
                 FTBaseInfoHanderDeviceCPUType:@"Vortex (x2) + Tempest (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2490MHz",
                 FTBaseInfoHanderBatteryTotal:@"30.2Wh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    
    //------------------------------iPad Mini-----------------------
    if ([platform isEqualToString:@"iPad2,5"] ||
        [platform isEqualToString:@"iPad2,6"] ||
        [platform isEqualToString:@"iPad2,7"]){
        return  @{FTBaseInfoHanderDeviceType:@"iPad mini",
                  FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A9",
                  FTBaseInfoHanderDeviceCPUClock:@"1000MHz",
                  FTBaseInfoHanderBatteryTotal:@"16.3Wh",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX543MP2",
        };
    }
    if ([platform isEqualToString:@"iPad4,4"] ||
        [platform isEqualToString:@"iPad4,5"] ||
        [platform isEqualToString:@"iPad4,6"]){
        return  @{FTBaseInfoHanderDeviceType:@"iPad mini 2",
                  FTBaseInfoHanderDeviceCPUType:@"Cyclone",
                  FTBaseInfoHanderDeviceCPUClock:@"1300MHz",
                  FTBaseInfoHanderBatteryTotal:@"16.3Wh",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR G6430",
        };
    }
    if ([platform isEqualToString:@"iPad4,7"] ||
        [platform isEqualToString:@"iPad4,8"] ||
        [platform isEqualToString:@"iPad4,9"]){
        return  @{FTBaseInfoHanderDeviceType:@"iPad mini 3",
                  FTBaseInfoHanderDeviceCPUType:@"Cyclone",
                  FTBaseInfoHanderDeviceCPUClock:@"1300MHz",
                  FTBaseInfoHanderBatteryTotal:@"23.8Wh",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR G6430",
        };
    }
    if ([platform isEqualToString:@"iPad5,1"] ||
        [platform isEqualToString:@"iPad5,2"]){
        return  @{FTBaseInfoHanderDeviceType:@"iPad mini 4",
                  FTBaseInfoHanderDeviceCPUType:@"Typhoon",
                  FTBaseInfoHanderDeviceCPUClock:@"1400MHz",
                  FTBaseInfoHanderBatteryTotal:@"19.1Wh",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR GX6450",
        };
    }
    if ([platform isEqualToString:@"iPad11,1"] ||
        [platform isEqualToString:@"iPad11,2"]){
        return @{FTBaseInfoHanderDeviceType:@"iPad mini 5",
                 FTBaseInfoHanderDeviceCPUType:@"Vortex (x2) + Tempest (x4)",
                 FTBaseInfoHanderDeviceCPUClock:@"2490MHz",
                 FTBaseInfoHanderBatteryTotal:@"19.1Wh",
                 FTBaseInfoHanderDeviceGPUType:@"Custom design",
        };
    }
    
    //------------------------------iTouch------------------------
    if ([platform isEqualToString:@"iPod1,1"]){
        return  @{FTBaseInfoHanderDeviceType:@"iTouch",
                  FTBaseInfoHanderDeviceCPUType:@"ARM1176JZ(F)-S v1.0",
                  FTBaseInfoHanderDeviceCPUClock:@"412MHz",
                  FTBaseInfoHanderBatteryTotal:@"unknown",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR MBX Lite",
        };
    }
    if ([platform isEqualToString:@"iPod2,1"]){
        return  @{FTBaseInfoHanderDeviceType:@"iTouch2",
                  FTBaseInfoHanderDeviceCPUType:@"ARM1176JZ(F)-S v1.0",
                  FTBaseInfoHanderDeviceCPUClock:@"532MHz",
                  FTBaseInfoHanderBatteryTotal:@"unknown",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR MBX Lite",
        };
    }
    if ([platform isEqualToString:@"iPod3,1"]){
        return  @{FTBaseInfoHanderDeviceType:@"iTouch3",
                  FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A8",
                  FTBaseInfoHanderDeviceCPUClock:@"600MHz",
                  FTBaseInfoHanderBatteryTotal:@"unknown",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX535",
        };
    }
    if ([platform isEqualToString:@"iPod4,1"]){
        return  @{FTBaseInfoHanderDeviceType:@"iTouch4",
                  FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A8",
                  FTBaseInfoHanderDeviceCPUClock:@"800MHz",
                  FTBaseInfoHanderBatteryTotal:@"unknown",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX535",
        };
    }
    if ([platform isEqualToString:@"iPod5,1"]){
        return  @{FTBaseInfoHanderDeviceType:@"iTouch5",
                  FTBaseInfoHanderDeviceCPUType:@"ARM Cortex-A9",
                  FTBaseInfoHanderDeviceCPUClock:@"800MHz",
                  FTBaseInfoHanderBatteryTotal:@"unknown",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR SGX543MP2",
        };
    }
    if ([platform isEqualToString:@"iPod7,1"]){
        return  @{FTBaseInfoHanderDeviceType:@"iTouch6",
                  FTBaseInfoHanderDeviceCPUType:@"Typhoon",
                  FTBaseInfoHanderDeviceCPUClock:@"1100MHz",
                  FTBaseInfoHanderBatteryTotal:@"unknown",
                  FTBaseInfoHanderDeviceGPUType:@"PowerVR GX6450",
        };
    }
    
    //------------------------------Samulitor-------------------------------------
    if ([platform isEqualToString:@"i386"] ||
        [platform isEqualToString:@"x86_64"]){
        return  @{FTBaseInfoHanderDeviceType:@"iPhone Simulator",
                  FTBaseInfoHanderDeviceCPUType:@"unknown",
                  FTBaseInfoHanderDeviceCPUClock:@"unknown",
                  FTBaseInfoHanderBatteryTotal:@"unknown",
                  FTBaseInfoHanderDeviceGPUType:@"unknown",
        };
    }
    
    
    return @{FTBaseInfoHanderDeviceType:platform,
             FTBaseInfoHanderDeviceCPUType:@"unknown",
             FTBaseInfoHanderDeviceCPUClock:@"unknown",
             FTBaseInfoHanderBatteryTotal:@"unknown",
             FTBaseInfoHanderDeviceGPUType:@"unknown",
    };
    
}
+(NSString *)ft_getTelephonyInfo
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
    if(carrier ==nil){
        return FT_NULL_VALUE;
    }else{
    NSString *mCarrier = [NSString stringWithFormat:@"%@",[carrier carrierName]];
    return mCarrier;
    }
}
+ (NSString *)ft_resolution {
    CGRect rect = [[UIScreen mainScreen] bounds];
    CGFloat scale = [[UIScreen mainScreen] scale];
    return [[NSString alloc] initWithFormat:@"%.f*%.f",rect.size.height*scale,rect.size.width*scale];
}
#pragma mark ========== 字符串转字典 字典转字符串 ==========
+(NSString *)ft_convertToJsonData:(NSDictionary *)dict
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString;
    if (!jsonData) {
        ZYErrorLog(@"ERROR == %@",error);
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    return mutStr;
    
}
+ (NSDictionary *)ft_dictionaryWithJsonString:(NSString *)jsonString
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
        ZYErrorLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}
#pragma mark ========== 请求加密 ==========
+ (NSString *)ft_md5base64EncryptStr:(NSString *)str {
    const char *input = [str UTF8String];//UTF8转码
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input, (CC_LONG)strlen(input), result);
    NSData *data = [NSData dataWithBytes: result length:16];
    NSString *string = [data base64EncodedStringWithOptions:0];//base64编码;
    return string;
}
+(NSString*)ft_getSignatureWithHTTPMethod:(NSString *)method contentType:(NSString *)contentType dateStr:(NSString *)dateStr akSecret:(NSString *)akSecret data:(NSString *)data
{
    NSMutableString *signString = [[NSMutableString alloc] init];
    
    [signString appendString:method];
    [signString appendString:@"\n"];
    [signString appendString:[self ft_md5base64EncryptStr:data]];
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
    return  NSStringFromClass(result.class);
    
}
@end
