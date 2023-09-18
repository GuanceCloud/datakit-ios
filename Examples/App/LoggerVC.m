//
//  LoggerVC.m
//  App
//
//  Created by hulilei on 2023/4/12.
//  Copyright © 2023 GuanceCloud. All rights reserved.
//

#import "LoggerVC.h"
#import "TableViewCellItem.h"
#import "App-Swift.h"
#import <FTMobileSDK/FTMobileSDK.h>
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
        [[FTMobileAgent sharedInstance] logging:datas[2] status:FTStatusWarning];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:datas[3] handler:^{
        [[FTLogger sharedInstance] critical:datas[3] property:@{@"critical_key":@"critical_value"}];
    }];
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:datas[4] handler:^{
        [[FTLogger sharedInstance] ok:datas[4] property:@{@"ok_key":@"ok_value",@"ok_key2":@"ok_value2"}];
    }];
    [self.dataSource addObjectsFromArray:@[item1,item2,item3,item4,item5]];
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200)];
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
