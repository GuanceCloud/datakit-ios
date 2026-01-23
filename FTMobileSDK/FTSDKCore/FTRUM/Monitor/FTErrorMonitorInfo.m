//
//  FTErrorMonitorInfo.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/9.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTErrorMonitorInfo.h"
#import "FTConstants.h"
#import "FTMonitorUtils.h"
#import "FTBaseInfoHandler.h"
#import "FTSDKCompat.h"
#if FT_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif
#if FT_HOST_IOS
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#endif
@interface FTErrorMonitorInfo()
@property (nonatomic, assign) ErrorMonitorType monitorType;
@property (nonatomic, copy) NSString *totalMemorySize;
@property (nonatomic, strong) NSNumber *batteryUse;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy) NSString *telephonyCarrier;
@property (nonatomic, copy) NSString *local;
@property (nonatomic, copy) ErrorMonitorInfoChangeBlock onChange;
#if FT_HOST_IOS
@property (nonatomic, strong) UIDevice *device;
@property (nonatomic, strong) CTTelephonyNetworkInfo *networkInfo;
#endif
@property (nonatomic, strong) id batteryNotificationObserver;
@property (nonatomic, strong) id telephonyNotificationObserver;
@property (nonatomic, strong) id localNotificationObserver;
@end
void *FTErrorMonitorInfoQueueTag = &FTErrorMonitorInfoQueueTag;

@implementation FTErrorMonitorInfo
- (instancetype)initWithMonitorType:(ErrorMonitorType)monitorType{
    self = [super init];
    if (self) {
        self.monitorType = monitorType;
        self.queue = dispatch_queue_create("com.ft.error-info",DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self.queue, FTErrorMonitorInfoQueueTag, &FTErrorMonitorInfoQueueTag, NULL);
        [self startMonitor];
    }
    return self;
}
- (void)startMonitor{
    if (self.monitorType & ErrorMonitorMemory) {
        self.totalMemorySize = [FTMonitorUtils totalMemorySize];
    }
    __weak __typeof(self) weakSelf = self;
#if FT_HOST_IOS
    if (self.monitorType & ErrorMonitorBattery) {
        self.device = [UIDevice currentDevice];
        self.device.batteryMonitoringEnabled = YES;
        _batteryUse = self.device.batteryLevel == -1? @0 : @(self.device.batteryLevel*100);
        if (self.batteryNotificationObserver) {
            [[NSNotificationCenter defaultCenter] removeObserver:self.batteryNotificationObserver];
        }
        
        self.batteryNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue  usingBlock:^(NSNotification * _Nonnull notification) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if ([notification.object isKindOfClass:UIDevice.class]) {
                UIDevice *device = notification.object;
                float batteryLevel = device.batteryLevel;
                strongSelf.batteryUse = batteryLevel == -1? @0 : @(batteryLevel*100);
            }
        }];
    }
#endif

    
#if FT_HOST_IOS
    // https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-16_4-release-notes#Core-Telephony
    //  CTCarrier, a deprecated API, returns static values for apps that are built with the iOS 16.4 SDK or later.
    if (@available(iOS 16.4, *)) {
        _telephonyCarrier = @"--";
    }else{
        self.networkInfo = [[CTTelephonyNetworkInfo alloc] init];
        if (@available(iOS 12.0, *)) {
            _telephonyCarrier = [self.networkInfo.serviceCurrentRadioAccessTechnology.allValues firstObject] ?: FT_NULL_VALUE;
        } else {
            _telephonyCarrier = [[self.networkInfo subscriberCellularProvider] carrierName] ?: FT_NULL_VALUE;
        }
        
        if (self.telephonyNotificationObserver) {
            [[NSNotificationCenter defaultCenter] removeObserver:self.telephonyNotificationObserver];
        }
        NSString *notificationName;
        if (@available(iOS 12.0, *)) {
            notificationName = CTServiceRadioAccessTechnologyDidChangeNotification;
        }else{
            notificationName = CTRadioAccessTechnologyDidChangeNotification;
        }
        self.telephonyNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:notificationName
                                                                                               object:self.networkInfo
                                                                                                queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(NSNotification * _Nonnull notification) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            NSString *newCarrier = @"";
            if (@available(iOS 12.0, *)) {
                NSString *key = notification.object;
                if (key && strongSelf.networkInfo.serviceCurrentRadioAccessTechnology[key]) {
                    newCarrier = strongSelf.networkInfo.serviceCurrentRadioAccessTechnology[key];
                }
            } else {
                newCarrier = [[strongSelf.networkInfo subscriberCellularProvider] carrierName] ?: @"";
            }
            strongSelf.telephonyCarrier = newCarrier ? : FT_NULL_VALUE;
        }];
    }
#endif
    if (self.localNotificationObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.localNotificationObserver];
    }
    _local = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    self.localNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.local = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    }];
    
    [self onChangeCallBack];
}
-(BOOL)enableMonitorCpu{
    return self.monitorType & ErrorMonitorCpu;
}
-(BOOL)enableMonitorMemory{
    return self.monitorType & ErrorMonitorMemory;
}
-(void)setBatteryUse:(NSNumber *)batteryUse{
    dispatch_async(self.queue, ^{
        if (![batteryUse isEqualToNumber:self.batteryUse]) {
            self->_batteryUse = batteryUse;
            [self onChangeCallBack];
        }
    });
}
- (void)setLocal:(NSString *)local{
    dispatch_async(self.queue, ^{
        if (![local isEqualToString:self.local]) {
            self->_local = local;
            [self onChangeCallBack];
        }
    });
}
-(void)setTelephonyCarrier:(NSString *)telephonyCarrier{
    dispatch_async(self.queue, ^{
        if (![telephonyCarrier isEqualToString:self.telephonyCarrier]) {
            self->_telephonyCarrier = telephonyCarrier;
            [self onChangeCallBack];
        }
    });
}
- (NSDictionary *)errorMonitorInfo{
    NSMutableDictionary *errorTag = [NSMutableDictionary new];
    dispatch_sync(self.queue, ^{
        if (self.monitorType & ErrorMonitorMemory) {
            errorTag[FT_MEMORY_TOTAL] = self.totalMemorySize;
            errorTag[FT_MEMORY_USE] = [NSNumber numberWithFloat:[FTMonitorUtils memoryUsage]];
        }
        if (self.monitorType & ErrorMonitorCpu) {
            errorTag[FT_CPU_USE] = [NSNumber numberWithLong:[FTMonitorUtils cpuUsage]];
        }
        if (self.monitorType & ErrorMonitorBattery) {
#if FT_HOST_IOS
            errorTag[FT_BATTERY_USE] = self.batteryUse;
#elif FT_HOST_MAC
            errorTag[FT_BATTERY_USE] =[NSNumber numberWithDouble:[FTMonitorUtils batteryUse]];
#endif
        }
#if FT_HOST_IOS
        errorTag[FT_KEY_CARRIER] = self.telephonyCarrier;
#endif
        errorTag[FT_KEY_LOCALE] = self.local;
    });
    return [errorTag copy];
}

- (void)onChangeCallBack{
    if (self.onChange) {
        self.onChange([self onChangeErrorMonitorInfo]);
    }
}
- (NSDictionary *)onChangeErrorMonitorInfo{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dispatch_block_t block = ^{
        dict[FT_MEMORY_TOTAL] = self.totalMemorySize;
        dict[FT_BATTERY_USE] = self.batteryUse;
        dict[FT_KEY_CARRIER] = self.telephonyCarrier;
        dict[FT_KEY_LOCALE] = self.local;
    };
    [self syncBlock:block];
    return [dict copy];
}
- (void)syncBlock:(dispatch_block_t)block{
    if (dispatch_get_specific(FTErrorMonitorInfoQueueTag)) {
        block();
    } else {
        dispatch_sync(self.queue, block);
    }
}
- (void)onErrorMonitorInfoChange:(ErrorMonitorInfoChangeBlock)onChange{
    dispatch_sync(self.queue, ^{
        self.onChange = onChange;
    });
}
- (void)dealloc {
    if (self.batteryNotificationObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.batteryNotificationObserver];
        self.batteryNotificationObserver = nil;
    }
    
    if (self.telephonyNotificationObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.telephonyNotificationObserver];
        self.telephonyNotificationObserver = nil;
    }
    if (self.localNotificationObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.localNotificationObserver];
        self.localNotificationObserver = nil;
    }
#if FT_HOST_IOS
    if (self.device) {
        self.device.batteryMonitoringEnabled = NO;
        self.device = nil;
    }
#endif
    
#if FT_HOST_IOS
    self.networkInfo = nil;
#endif
}
@end
