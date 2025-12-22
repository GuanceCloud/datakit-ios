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
@interface FTErrorMonitorInfo()
@property (nonatomic, assign) ErrorMonitorType monitorType;
@property (nonatomic, copy) NSString *totalMemorySize;
@property (nonatomic, strong) NSNumber *batteryUse;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy) NSString *telephonyCarrier;
@property (nonatomic, copy) NSString *local;
@property (nonatomic, copy) ErrorMonitorInfoChangeBlock onChange;
#if FT_HAS_UIDEVICE
@property (nonatomic, strong) UIDevice *device;
#endif

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
#if FT_HAS_UIDEVICE
    if (self.monitorType & ErrorMonitorBattery) {
        self.device = [UIDevice currentDevice];
        self.device.batteryMonitoringEnabled = YES;
        self->_batteryUse = self.device.batteryLevel == -1? @0 : @(self.device.batteryLevel*100);
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull notification) {
            if ([notification.object isKindOfClass:UIDevice.class]) {
                UIDevice *device = notification.object;
                float batteryLevel = device.batteryLevel;
                self.batteryUse = batteryLevel == -1? @0 : @(batteryLevel*100);
            }
        }];
    }
#endif
    
}

-(void)setBatteryUse:(NSNumber *)batteryUse{
    dispatch_async(self.queue, ^{
        if (![batteryUse isEqualToNumber:self.batteryUse]) {
            self.batteryUse = batteryUse;
            [self onChangeCallBack];
        }
    });
}
- (void)setLocal:(NSString *)local{
    dispatch_async(self.queue, ^{
        if (![local isEqualToString:self.local]) {
            self.local = local;
            [self onChangeCallBack];
        }
    });
}
-(void)setTelephonyCarrier:(NSString *)telephonyCarrier{
    dispatch_async(self.queue, ^{
        if (![telephonyCarrier isEqualToString:self.telephonyCarrier]) {
            self.telephonyCarrier = telephonyCarrier;
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
#if FT_HAS_UIDEVICE
            errorTag[FT_BATTERY_USE] = self.batteryUse;
#elif FT_HOST_MAC
            errorTag[FT_BATTERY_USE] =[NSNumber numberWithDouble:[FTMonitorUtils batteryUse]];
#endif
        }
#if FT_HOST_IOS
        errorTag[FT_KEY_CARRIER] = [FTBaseInfoHandler telephonyCarrier];
#endif
        NSString *preferredLanguage = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
        errorTag[FT_KEY_LOCALE] = preferredLanguage;
    });
    return [errorTag copy];
}

- (void)onChangeCallBack{
    if (self.onChange) {
        self.onChange([self currentErrorMonitorInfo]);
    }
}
- (NSDictionary *)currentErrorMonitorInfo{
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

@end
