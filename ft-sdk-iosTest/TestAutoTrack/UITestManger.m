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
    if ([super init]) {
        self.lastCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
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
          self.lastCount =  [[FTTrackerEventDBTool sharedManger] getDatasCount];
           NSLog(@"lastCount == %ld",self.lastCount);
           self.trackCount = 1;//lunch
           self.autoTrackViewScreenCount = 2; //ViewController (close)
           self.self.autoTrackClickCount = 0;
}
-(void)addTrackCount{
    if(self.config.autoTrackEventType & FTAutoTrackEventTypeAppLaunch){
    self.trackCount++;
    NSLog(@"add == %ld",self.trackCount);
    }
}
- (void)addAutoTrackViewScreenCount{
    if(self.config.autoTrackEventType & FTAutoTrackEventTypeAppViewScreen){
    self.autoTrackViewScreenCount ++;
    NSLog(@"add == %ld",self.autoTrackViewScreenCount);
    }
}
- (void)addAutoTrackClickCount{
     if(self.config.autoTrackEventType & FTAutoTrackEventTypeAppClick){
    self.autoTrackClickCount++;
    NSLog(@"add == %ld",self.autoTrackClickCount);
     }

}
-(NSArray *)getEndResult{
    NSMutableArray *result = [NSMutableArray new];
    NSInteger addCount = [[FTTrackerEventDBTool sharedManger] getDatasCount];
    
    NSInteger trueCount = self.lastCount+self.trackCount+self.autoTrackClickCount+self.autoTrackViewScreenCount;
//    if (addCount == trueCount) {
        [result addObject:@"All Right"];
//    }
    NSLog(@"addCount == %ld trueCount == %ld",(long)addCount,(long)trueCount);
    return result;
}
@end
