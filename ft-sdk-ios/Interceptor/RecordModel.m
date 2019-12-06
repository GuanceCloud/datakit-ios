//
//  RecordModel.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "RecordModel.h"
#import "ZYBaseInfoHander.h"

@implementation RecordModel
-(instancetype)init{
   self = [super init];
    if (self) {
        self.tm = [ZYBaseInfoHander getCurrentTimestamp];
    }
    return self;
}
@end
