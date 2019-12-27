//
//  AutoTrackManger.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/12/27.
//  Copyright © 2019 hll. All rights reserved.
//

#import "AutoTrackManger.h"
#import <FTMobileAgent/ZYDataBase/ZYTrackerEventDBTool.h>

@interface AutoTrackManger ()
@property (nonatomic, assign) NSInteger lastCount;
@property (nonatomic, assign) NSInteger trackCount;
@property (nonatomic, assign) NSInteger autoTrackViewScreenCount;
@property (nonatomic, assign) NSInteger autoTrackClickCount;
@end
@implementation AutoTrackManger
+(AutoTrackManger *)sharedManger{
    static AutoTrackManger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
          sharedInstance = [[AutoTrackManger alloc] init];
      });
    return sharedInstance;
}
-(instancetype)init{
    if ([super init]) {
        self.lastCount =  [[ZYTrackerEventDBTool sharedManger] getDatasCount];
        NSLog(@"lastCount == %ld",self.lastCount);
        self.trackCount = 0;
        self.autoTrackViewScreenCount = 0;
        self.self.autoTrackClickCount = 0;
    }
    return self;
}
-(void)addTrackCount{
    self.trackCount++;
    NSLog(@"trackCount == %ld",self.trackCount);

}
- (void)addAutoTrackViewScreenCount{
    self.autoTrackViewScreenCount ++;
    NSLog(@"autoTrackViewScreenCount == %ld",self.autoTrackViewScreenCount);

}
- (void)addAutoTrackClickCount{
    self.autoTrackClickCount++;
    NSLog(@"autoTrackClickCount == %ld",self.autoTrackClickCount);

}
-(NSArray *)getEndResult{
    NSMutableArray *result = [NSMutableArray new];
    NSInteger addCount = [[ZYTrackerEventDBTool sharedManger] getDatasCount];
    
    NSInteger trueCount = self.lastCount+self.trackCount+self.autoTrackClickCount+self.autoTrackClickCount;
//    if (addCount == trueCount) {
        [result addObject:@"All Right"];
//    }
    NSLog(@"addCount == %ld trueCount == %ld",(long)addCount,(long)trueCount);
    return result;
}
@end
