//
//  LoggerVC.m
//  App
//
//  Created by hulilei on 2023/4/12.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
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

#import "LoggerVC.h"
#import "TableViewCellItem.h"
#import "App-Swift.h"
#import <GuanceSDK/GuanceSDK.h>
@interface LoggerVC()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSMutableArray<TableViewCellItem*> *dataSource;
@end
@implementation LoggerVC
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Logger";
    [self createUI];
}
- (void)createUI{
    self.dataSource = [NSMutableArray new];
    NSArray *datas = @[@"Log Status: info",
                       @"Log Status: warning",
                       @"Log Status: error",
                       @"Log Status: critical",
                       @"Log Status: ok",
    ];
    TableViewCellItem *item1 = [[TableViewCellItem alloc]initWithTitle:datas[0] handler:^{
        [[FTMobileAgent sharedInstance] logging:datas[0] status:FTStatusInfo];
    }];
    TableViewCellItem *item2 = [[TableViewCellItem alloc]initWithTitle:datas[1] handler:^{
        [[FTMobileAgent sharedInstance] logging:datas[1] status:FTStatusWarning];
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:datas[2] handler:^{
        [[FTMobileAgent sharedInstance] logging:datas[2] status:FTStatusError];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:datas[3] handler:^{
        [[FTLogger sharedInstance] critical:datas[3] property:@{@"critical_key":@"critical_value"}];
    }];
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:datas[4] handler:^{
        [[FTLogger sharedInstance] ok:datas[4] property:@{@"ok_key":@"ok_value",@"ok_key2":@"ok_value2"}];
    }];
    [self.dataSource addObjectsFromArray:@[item1,item2,item3,item4,item5]];
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    [self.view addSubview:_mtableView];
    
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataSource.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.textLabel.text = self.dataSource[indexPath.row].title;
    cell.accessibilityLabel = self.dataSource[indexPath.row].title;
    cell.isAccessibilityElement = YES;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    TableViewCellItem *item = self.dataSource[indexPath.row];
    if (item.handler) {
        item.handler();
    }
}
@end
