//
//  SplitViewVC.m
//  Example
//
//  Created by hulilei on 2021/9/26.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import "SplitViewVC.h"
#import "SplitViewItemVC2.h"
@interface SplitViewVC ()

@end

@implementation SplitViewVC

- (void)viewDidLoad {
    [super viewDidLoad];
    for (NSSplitViewItem *item in self.splitViewItems) {
        NSLog(@"NSSplitViewItem viewController = %@",item.viewController);

    }
    // Do view setup here.
}
- (void)tableViewSelectionDidSelect:(NSInteger)index{
    SplitViewItemVC2 *item2 = (SplitViewItemVC2 *)self.splitViewItems[1].viewController;
    [item2 showViewIndex:index];
}
@end
