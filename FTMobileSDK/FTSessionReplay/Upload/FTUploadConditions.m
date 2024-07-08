//
//  FTUploadConditions.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "FTUploadConditions.h"
#import "FTSDKCompat.h"
#import "FTReachability.h"
typedef void (^NotificationBlock)(NSNotification *);
@interface FTUploadConditions()
@property (nonatomic, assign) BOOL lowPowerModeEnabled;
@property (nonatomic, strong) UIDevice *device;
@property (nonatomic, assign) BOOL isReachable;
@property (nonatomic, assign) UIDeviceBatteryState batteryState;
@property (nonatomic, assign) float batteryLevel;
@property (nonatomic, strong) NSArray *observers;
@end
@implementation FTUploadConditions
-(instancetype)init{
    self = [super init];
    if(self){
        _device = [UIDevice currentDevice];
        _device.batteryMonitoringEnabled = YES;
    }
    return self;
}
- (void)startObserver{
    __weak typeof(self) weakSelf = self;
    [[FTReachability sharedInstance] startNotifier];
    [FTReachability sharedInstance].networkChanged = ^(){
        weakSelf.isReachable = [FTReachability sharedInstance].isReachable;
    };
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NotificationBlock block = ^(NSNotification *notification){
        if([notification.object isKindOfClass:NSProcessInfo.class]){
            NSProcessInfo *info = notification.object;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                weakSelf.lowPowerModeEnabled = info.lowPowerModeEnabled;
            }];
        }else if ([notification.object isKindOfClass:UIDevice.class]){
            UIDevice *device = notification.object;
            weakSelf.batteryState = device.batteryState;
            weakSelf.batteryLevel = device.batteryLevel;
        }
    };
    NSMutableArray *array = [NSMutableArray new];
#if FT_IOS
   id levelObserver = [notificationCenter addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue usingBlock:block];
    id stateObserver = [notificationCenter addObserverForName:UIDeviceBatteryStateDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue usingBlock:block];
    [array addObjectsFromArray:@[levelObserver,stateObserver]];
#endif
   id processObserver = [notificationCenter addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:block];
    
    [array addObject:processObserver];
    self.observers = array;
}
- (BOOL)checkForUpload{
    if(!self.isReachable){
        return NO;
    }
    if(self.lowPowerModeEnabled){
        return NO;
    }
    BOOL batteryFullOrCharging = self.batteryState == UIDeviceBatteryStateCharging || self.batteryState == UIDeviceBatteryStateFull;

    BOOL batteryLevelIsEnough = self.batteryLevel > 0.1;
    
    if(!batteryLevelIsEnough && !batteryFullOrCharging){
        return NO;
    }
    return YES;
}
- (void)cancel{
    for (id observer in self.observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
}
@end
