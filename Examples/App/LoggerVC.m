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
#import <FTMobileSDK/FTMobileAgent.h>
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
    for (int i=0; i<datas.count;i++) {
        TableViewCellItem *item = [[TableViewCellItem alloc]initWithTitle:datas[i] handler:^{
                [[FTMobileAgent sharedInstance] logging:datas[i] status:(FTLogStatus)i];
            }];
        [self.dataSource addObject:item];
    }
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
