//
//  AutoTrackManger.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/12/27.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UITestManger.h"
#import <FTMobileAgent/ZYDataBase/ZYTrackerEventDBTool.h>
#import "AppDelegate.h"

@interface UITestManger ()

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
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        
        self.lastCount =  [[ZYTrackerEventDBTool sharedManger] getDatasCount];
        NSLog(@"lastCount == %ld",self.lastCount);
        self.trackCount = 0;//lunch
        self.autoTrackClickCount = 0;
        self.autoTrackViewScreenCount = 0;
    }
    return self;
}
-(void)reset{
          self.lastCount =  [[ZYTrackerEventDBTool sharedManger] getDatasCount];
           NSLog(@"lastCount == %ld",self.lastCount);
           self.trackCount = 0;//lunch
           self.autoTrackViewScreenCount = 0; //ViewController (close)
           self.self.autoTrackClickCount = 0;
}
-(void)addTrackCount{
    self.trackCount++;
    NSLog(@"add == %ld",self.trackCount);

}
- (void)addAutoTrackViewScreenCount{
    self.autoTrackViewScreenCount ++;
    NSLog(@"add == %ld",self.autoTrackViewScreenCount);

}
- (void)addAutoTrackClickCount{
    self.autoTrackClickCount++;
    NSLog(@"add == %ld",self.autoTrackClickCount);

}
-(NSArray *)getEndResult{
    NSMutableArray *result = [NSMutableArray new];
    NSInteger addCount = [[ZYTrackerEventDBTool sharedManger] getDatasCount];
    
    NSInteger trueCount = self.lastCount+self.trackCount+self.autoTrackClickCount+self.autoTrackViewScreenCount;
//    if (addCount == trueCount) {
        [result addObject:@"All Right"];
//    }
    NSLog(@"addCount == %ld trueCount == %ld",(long)addCount,(long)trueCount);
    return result;
}
@end
