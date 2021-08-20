//
//  FTTaskInterceptionModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/27.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTTaskInterceptionModel.h"

@implementation FTTaskInterceptionModel
-(instancetype)init{
    self = [super init];
    if (self) {
        self.identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
@end
