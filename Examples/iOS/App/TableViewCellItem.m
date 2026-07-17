//
//  TableViewCellItem.m
//  SampleApp
//
//  Created by hulilei on 2021/2/19.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
