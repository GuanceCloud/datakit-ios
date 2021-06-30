//
//  TableViewCellItem.m
//  SampleApp
//
//  Created by 胡蕾蕾 on 2021/2/19.
//  Copyright © 2021 hll. All rights reserved.
//

#import "TableViewCellItem.h"

@implementation TableViewCellItem
-(instancetype)initWithTitle:(NSString *)title handler:(Handler)handler{
    self = [super init];
    if (self) {
        self.title = title;
        self.handler = handler;
    }
    return self;
}

@end
