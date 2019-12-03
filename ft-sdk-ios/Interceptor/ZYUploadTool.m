//
//  ZYUploadTool.m
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ZYUploadTool.h"
#import <UIKit/UIKit.h>

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "ZYDeviceInfoHander.h"
@interface ZYUploadTool()
@property (nonatomic, strong) NSDictionary *tag;
@end
@implementation ZYUploadTool


- (NSDictionary *)getBasicData{
    if (_tag != nil) {
        return _tag;
    }
    CFUUIDRef puuid = CFUUIDCreate ( nil ) ;
    CFStringRef uuidString = CFUUIDCreateString ( nil , puuid ) ;
    NSString* uuid = (NSString*)CFBridgingRelease(CFStringCreateCopy(NULL, uuidString));
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    CFShow((__bridge CFTypeRef)(infoDictionary));
    NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
    NSString *identifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
    NSString *app_Version = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
    
   
    NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    NSString *version = [UIDevice currentDevice].systemVersion;


    NSDictionary *tag = @{@"device_uuid":uuid,
                          @"application_identifier":identifier,
                          @"application_name":app_Name,
                          @"sdk_version":app_Version,
                          @"imei":@"",
                          @"os":@"iOS",
                          @"os_version":version,
                          @"locale":preferredLanguage,
                          @"device_band":@"",
                          @"device_model":[ZYDeviceInfoHander getDeviceType],
                          @"display":[ZYDeviceInfoHander resolution],
                          @"carrier":[ZYDeviceInfoHander getTelephonyInfo],
    };
    _tag = tag;
    return _tag;
}

@end
