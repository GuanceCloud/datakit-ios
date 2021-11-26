//
//  FTResourceContentModel.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTResourceContentModel.h"

@implementation FTResourceContentModel
-(instancetype)init{
    self = [super init];
    if (self) {
        self.httpMethod = @"";
        self.responseBody = @"";
        self.httpStatusCode = -1;
    }
    return self;
}
@end

