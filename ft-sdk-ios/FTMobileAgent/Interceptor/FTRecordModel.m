//
//  RecordModel.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTRecordModel.h"
#import "ZYBaseInfoHander.h"

@implementation FTRecordModel
-(instancetype)init{
   self = [super init];
    if (self) {
        self.tm = [ZYBaseInfoHander getCurrentTimestamp];
        NSString *sessionid;
           sessionid =get_ft_sessionid;
           if (!sessionid) {
               sessionid = [[NSUUID UUID] UUIDString];
               set_ft_sessionid(sessionid);
               [[NSUserDefaults standardUserDefaults] synchronize];
           }
        self.sessionid = sessionid;
    }
    return self;
}
@end
