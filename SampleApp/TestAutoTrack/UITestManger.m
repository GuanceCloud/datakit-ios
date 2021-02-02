//
//  AutoTrackManger.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/12/27.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UITestManger.h"
#import <FTMobileAgent/FTDataBase/FTTrackerEventDBTool.h>
#import <FTMobileAgent/FTMobileConfig.h>
#import "AppDelegate.h"
@interface UITestManger ()
@property (nonatomic, strong) FTMobileConfig *config;
@end
@implementation UITestManger
+(UITestManger *)sharedManger{
    static UITestManger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[UITestManger alloc] init];
    });
    return sharedInstance;
}
-(instancetype)init{
    if (self = [super init]) {
        self.lastCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:@"metrics"];
        NSLog(@"lastCount == %ld",self.lastCount);
        self.trackCount = 1;//lunch
        self.autoTrackClickCount = 0;
        self.autoTrackViewScreenCount = 1;
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        self.config = appDelegate.config;
    }
    return self;
}
-(void)reset{
    self.lastCount =  [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:@"metrics"];
    NSLog(@"lastCount == %ld",self.lastCount);
    self.trackCount = 1;//lunch
    self.autoTrackViewScreenCount = 1; //UITabBarController (open)
    self.self.autoTrackClickCount = 0;
}
-(void)addTrackCount{
   
}
- (void)addAutoTrackViewScreenCount{
   
}
- (void)addAutoTrackClickCount{
   
}

@end
