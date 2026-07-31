//
//  FTUploadConditions.m
//  SessionReplay
//
//  Created by hulilei on 2024/7/5.
//
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif
#import <TargetConditionals.h>
#import "FTUploadConditions.h"
#import "FTSessionReplayCoreImports.h"
typedef void (^NotificationBlock)(NSNotification *);

#if TARGET_OS_IOS
static NSString *FTStringFromBatteryState(UIDeviceBatteryState state) {
    switch (state) {
        case UIDeviceBatteryStateUnknown:
            return @"Unknown";
        case UIDeviceBatteryStateUnplugged:
            return @"Unplugged";
        case UIDeviceBatteryStateCharging:
            return @"Charging";
        case UIDeviceBatteryStateFull:
            return @"Full";
        default:
            return @"Unknown";
    }
}
#endif
@interface FTUploadConditions()
@property (nonatomic, assign) BOOL lowPowerModeEnabled;
#if TARGET_OS_IOS
@property (nonatomic, strong) UIDevice *device;
@property (nonatomic, assign) UIDeviceBatteryState batteryState;
@property (nonatomic, assign) float batteryLevel;
#endif
@property (nonatomic, assign) BOOL isReachable;
@property (nonatomic, strong) NSArray *observers;
@end
@implementation FTUploadConditions
-(instancetype)init{
    self = [super init];
    if(self){
#if TARGET_OS_IOS
        _device = [UIDevice currentDevice];
        _device.batteryMonitoringEnabled = YES;
#endif
    }
    return self;
}
- (void)startObserver{
    __weak typeof(self) weakSelf = self;
    [[FTNetworkConnectivity sharedInstance] start];
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
#if TARGET_OS_IOS
    self.lowPowerModeEnabled = NSProcessInfo.processInfo.lowPowerModeEnabled;
    self.batteryState = self.device.batteryState;
    self.batteryLevel = self.device.batteryLevel;
#elif TARGET_OS_OSX
    if (@available(macOS 12.0, *)) {
        self.lowPowerModeEnabled = NSProcessInfo.processInfo.lowPowerModeEnabled;
    }
#endif
    NotificationBlock block = ^(NSNotification *notification){
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if([notification.object isKindOfClass:NSProcessInfo.class]){
            NSProcessInfo *info = notification.object;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                #if TARGET_OS_IOS
                strongSelf.lowPowerModeEnabled = info.lowPowerModeEnabled;
                #elif TARGET_OS_OSX
                if (@available(macOS 12.0, *)) {
                    strongSelf.lowPowerModeEnabled = info.lowPowerModeEnabled;
                }
                #endif
            }];
#if TARGET_OS_IOS
        }else if ([notification.object isKindOfClass:UIDevice.class]){
            UIDevice *device = notification.object;
            strongSelf.batteryState = device.batteryState;
            strongSelf.batteryLevel = device.batteryLevel;
#endif
        }
    };
    NSMutableArray *array = [NSMutableArray new];
#if TARGET_OS_IOS
   id levelObserver = [notificationCenter addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue usingBlock:block];
    id stateObserver = [notificationCenter addObserverForName:UIDeviceBatteryStateDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue usingBlock:block];
    [array addObjectsFromArray:@[levelObserver,stateObserver]];
#endif
    #if TARGET_OS_IOS
    id processObserver = [notificationCenter addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:block];
    [array addObject:processObserver];
    #elif TARGET_OS_OSX
    if (@available(macOS 12.0, *)) {
        id processObserver = [notificationCenter addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:block];
        [array addObject:processObserver];
    }
    #endif
    self.observers = array;
}
- (NSArray *)checkForUpload{
    NSMutableArray *conditions = [[NSMutableArray alloc]init];
    if(![FTNetworkInfoManager sharedInstance].isNetworkConfigured){
        [conditions addObject:@"Upload URL Not Configured"];
        return conditions;
    }
    if(![FTNetworkConnectivity sharedInstance].isConnected){
        [conditions addObject:@"Network Unreachable"];
    }
#if TARGET_OS_IOS
    if(self.batteryState == UIDeviceBatteryStateUnknown){
        return conditions;
    }
    BOOL batteryFullOrCharging = self.batteryState == UIDeviceBatteryStateCharging || self.batteryState == UIDeviceBatteryStateFull;

    BOOL batteryLevelIsEnough = self.batteryLevel > 0.1;
    
    if(!(batteryLevelIsEnough || batteryFullOrCharging)){
        [conditions addObject:[NSString stringWithFormat:@"Battery Level: %f ,Battery State: %@",self.batteryLevel*100,FTStringFromBatteryState(self.batteryState)]];
    }
#endif
    if(self.lowPowerModeEnabled){
        [conditions addObject:@"Battery Low Power Mode On"];
    }
    return conditions;
}
- (void)cancel{
    for (id observer in self.observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
}
-(void)dealloc{
    [self cancel];
}
@end

#endif
