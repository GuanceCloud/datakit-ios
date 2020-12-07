//
//  FTRecordModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTRecordModel.h"
#import "FTBaseInfoHander.h"
#import "NSDate+FTAdd.h"
@implementation FTRecordModel
-(instancetype)init{
   self = [super init];
    if (self) {
        self.tm = [[NSDate date] ft_dateTimestamp];
        self.sessionid = [FTBaseInfoHander ft_getSessionid];
        self.op = @"";
    }
    return self;
}
@end
