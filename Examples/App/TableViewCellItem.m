//
//  TableViewCellItem.m
//  SampleApp
//
//  Created by hulilei on 2021/2/19.
//  Copyright © 2021 hll. All rights reserved.
//

#import "TableViewCellItem.h"

@implementation TableViewCellItem
-(instancetype)initWithTitle:(NSString *)title handler:(Handler)handler{
    return [self initWithTitle:title subTitle:@"" handler:handler];
}
-(instancetype)initWithTitle:(NSString *)title subTitle:(NSString *)subTitle handler:(Handler)handler{
    self = [super init];
    if (self) {
        self.title = title;
        self.subTitle = subTitle;
        self.handler = handler;
    }
    return self;
}
@end
