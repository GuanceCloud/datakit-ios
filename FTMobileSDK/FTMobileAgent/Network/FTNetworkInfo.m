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
#import "FTConstants.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#define kDevice_Is_iPhoneX \
({BOOL isPhoneX = NO;\
if (@available(iOS 11.0, *)) {\
isPhoneX = [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom > 0.0;\
}\
(isPhoneX);})
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
+ (int)getNetSignalStrength{
    
    int signalStrength = 0;
//        判断是否为iOS 13
        if (@available(iOS 13.0, *)) {
            UIStatusBarManager *statusBarManager = [UIApplication sharedApplication].keyWindow.windowScene.statusBarManager;
             
            id statusBar = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            if ([statusBarManager respondsToSelector:@selector(createLocalStatusBar)]) {
                UIView *localStatusBar = [statusBarManager performSelector:@selector(createLocalStatusBar)];
                if ([localStatusBar respondsToSelector:@selector(statusBar)]) {
                    statusBar = [localStatusBar performSelector:@selector(statusBar)];
                }
            }
#pragma clang diagnostic pop
            if (statusBar) {
                id currentData = [[statusBar valueForKeyPath:@"_statusBar"] valueForKeyPath:@"currentData"];
                if([[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]){
                    id wifiEntry = [currentData valueForKeyPath:@"wifiEntry"];
                    if ([wifiEntry isKindOfClass:NSClassFromString(@"_UIStatusBarDataIntegerEntry")]) {
                        signalStrength = [[wifiEntry valueForKey:@"displayValue"] intValue];
                    }
                }
                if (![[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]) {
                     id cellularEntry  = [currentData valueForKeyPath:@"cellularEntry"];
                  if ([cellularEntry isKindOfClass:NSClassFromString(@"_UIStatusBarDataCellularEntry")]) {
                         //                    层级：_UIStatusBarDataNetworkEntry、_UIStatusBarDataIntegerEntry、_UIStatusBarDataEntry
                                             
                             signalStrength = [[cellularEntry valueForKey:@"displayValue"] intValue];
                         }
                }
            }
        }else {
            UIApplication *app = [UIApplication sharedApplication];
            id statusBar = [app valueForKey:@"statusBar"];
            if (kDevice_Is_iPhoneX) {
//                刘海屏
                id statusBarView = [statusBar valueForKeyPath:@"statusBar"];
                UIView *foregroundView = [statusBarView valueForKeyPath:@"foregroundView"];
                NSArray *subviews = [[foregroundView subviews][2] subviews];
                       
                if (subviews.count == 0) {
//                    iOS 12
                    id currentData = [statusBarView valueForKeyPath:@"currentData"];
                   if([[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]){
                        id wifiEntry = [currentData valueForKeyPath:@"wifiEntry"];
                        if ([wifiEntry isKindOfClass:NSClassFromString(@"_UIStatusBarDataIntegerEntry")]) {
                            signalStrength = [[wifiEntry valueForKey:@"displayValue"] intValue];
                        }
                    }
                    if (![[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]) {
                         id cellularEntry  = [currentData valueForKeyPath:@"cellularEntry"];
                      if ([cellularEntry isKindOfClass:NSClassFromString(@"_UIStatusBarDataCellularEntry")]) {
                             //                    层级：_UIStatusBarDataNetworkEntry、_UIStatusBarDataIntegerEntry、_UIStatusBarDataEntry
                                                 
                                 signalStrength = [[cellularEntry valueForKey:@"displayValue"] intValue];
                             }
                    }

                }else {
                    for (id subview in subviews) {
                        if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]] && [[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]) {
                            signalStrength = [[subview valueForKey:@"_wifiStrengthBars"] intValue];
                            break;
                        }
                        if ([subview isKindOfClass:[NSClassFromString(@"UIStatusBarSignalStrengthItemView") class]] && ![[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]) {
                            signalStrength = [[subview valueForKey:@"_signalStrengthRaw"] intValue];
                            break;
                        }
                    }
                }
            }else {
//                非刘海屏
                UIView *foregroundView = [statusBar valueForKey:@"foregroundView"];
                     
                NSArray *subviews = [foregroundView subviews];
                NSString *dataNetworkItemView = nil;
                       
                for (id subview in subviews) {
                    if([subview isKindOfClass:[NSClassFromString(@"UIStatusBarDataNetworkItemView") class]] && [[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]) {
                        dataNetworkItemView = subview;
                        signalStrength = [[dataNetworkItemView valueForKey:@"_wifiStrengthBars"] intValue];
                        break;
                    }
                    if ([subview isKindOfClass:[NSClassFromString(@"UIStatusBarSignalStrengthItemView") class]] && ![[self getNetworkType] isEqualToString:@"WIFI"] && ![[self getNetworkType] isEqualToString:FT_NULL_VALUE]) {
                        dataNetworkItemView = subview;
                        signalStrength = [[dataNetworkItemView valueForKey:@"_signalStrengthRaw"] intValue];
                        break;
                    }
                }
               
                        
                return signalStrength;
            }
        }
    
    return signalStrength;
}
+ (NSString *)getProxyHost {
    NSDictionary *proxySettings =  (__bridge NSDictionary *)(CFNetworkCopySystemProxySettings());
    NSArray *proxies = (__bridge NSArray *)(CFNetworkCopyProxiesForURL((__bridge CFURLRef _Nonnull)([NSURL URLWithString:@"http://www.baidu.com"]), (__bridge CFDictionaryRef _Nonnull)(proxySettings)));
    NSDictionary *settings = [proxies objectAtIndex:0];
    NSString *host= [settings objectForKey:(NSString *)kCFProxyHostNameKey];
    if (!host) {
        return FT_NULL_VALUE;
    }
    return host;
}
@end
