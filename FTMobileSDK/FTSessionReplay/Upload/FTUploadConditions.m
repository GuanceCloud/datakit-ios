//
//  FTUploadConditions.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "FTUploadConditions.h"
typedef void (^NotificationBlock)(NSNotification *);
@interface FTUploadConditions()
@property (nonatomic, assign) BOOL lowPowerModeEnabled;
@property (nonatomic, strong) UIDevice *device;
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
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NotificationBlock block = ^(NSNotification *notification){
        if([notification.object isKindOfClass:NSProcessInfo.class]){
            NSProcessInfo *info = notification.object;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                weakSelf.lowPowerModeEnabled = info.lowPowerModeEnabled;
            }];
        }else if ([notification.object isKindOfClass:UIDevice.class]){
            UIDevice *device = notification.object;
            
        }
    };
   id observer = [notificationCenter addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue usingBlock:block];
    [notificationCenter addObserverForName:UIDeviceBatteryStateDidChangeNotification object:self.device queue:NSOperationQueue.mainQueue usingBlock:block];
    
    
    [notificationCenter addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:block];
    
    
}
- (void)cancel{
    
}
@end
