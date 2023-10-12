//
//  DemoViewController.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "DemoViewController.h"
#import "UITestVC.h"
#import <FTMobileSDK/FTMobileAgent.h>
//测试崩溃采集
#import "TestLongTaskVC.h"
#import "TestWKWebViewVC.h"
#import "CrashVC.h"
#import "TableViewCellItem.h"
#import "App-Swift.h"
#import "TestJsbridgeData.h"
#import "ManualRumAndTraceDataAdd.h"
#import "NetworkTraceVC.h"
#import "LoggerVC.h"
@interface DemoViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSMutableArray<TableViewCellItem*> *dataSource;

@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self createUI];
}
-(NSMutableArray<TableViewCellItem *> *)dataSource{
    if (!_dataSource) {
        _dataSource = [[NSMutableArray alloc]init];
    }
    return _dataSource;
}
-(void)createUI{
    __weak typeof(self) weakSelf = self;
    TableViewCellItem *item1 = [[TableViewCellItem alloc]initWithTitle:@"EventFlowLog" handler:^{
        [weakSelf.navigationController pushViewController:[UITestVC new] animated:YES];
    }];
    TableViewCellItem *item2 = [[TableViewCellItem alloc]initWithTitle:@"BindUser" handler:^{
        [[FTMobileAgent sharedInstance] bindUserWithUserID:@"user1" userName:@"用户1" userEmail:@"1@qq.com" extra:@{@"user_age":@21}];
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:@"UserLogout" handler:^{
        [[FTMobileAgent sharedInstance] unbindUser];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:@"Network data collection" handler:^{
        [weakSelf.navigationController pushViewController:[NetworkTraceVC new] animated:YES];
    }];
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:@"webview data collection" handler:^{
        [weakSelf.navigationController pushViewController:[TestWKWebViewVC new] animated:YES];
    }];
    TableViewCellItem *item7 = [[TableViewCellItem alloc]initWithTitle:@"Custom Logger" handler:^{
        [weakSelf.navigationController pushViewController:[LoggerVC new] animated:YES];

    }];
    TableViewCellItem *item8 = [[TableViewCellItem alloc]initWithTitle:@"TrackAppLongTask" handler:^{
        [weakSelf.navigationController pushViewController:[TestLongTaskVC new] animated:YES];
    }];
    TableViewCellItem *item9 = [[TableViewCellItem alloc]initWithTitle:@"TrackAppCrash" handler:^{
        [weakSelf.navigationController pushViewController:[CrashVC new] animated:YES];
    }];
    TableViewCellItem *item10 = [[TableViewCellItem alloc]initWithTitle:@"WebViewBridge" handler:^{
        [weakSelf.navigationController pushViewController:[TestJsbridgeData new] animated:YES];
    }];
    TableViewCellItem *item11 = [[TableViewCellItem alloc]initWithTitle:@"globalContext dynamic tag" handler:^{
        NSInteger i = arc4random();
        [[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"dynamic_tags%ld",(long)i] forKey:@"DYNAMIC_TAG"];
    }];
    TableViewCellItem *item12 = [[TableViewCellItem alloc]initWithTitle:@"Manual Rum、Trace Data Add" handler:^{
        [weakSelf.navigationController pushViewController:[ManualRumAndTraceDataAdd new] animated:YES];

    }];
   
    [self.dataSource addObjectsFromArray:@[item1,item2,item3,item4,item5,item7,item8,item9,item10,item11,item12]];
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    [self.view addSubview:_mtableView];
    
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
}
-(void)showResult:(NSString *)title{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *commit = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:commit];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark ========== UITableViewDataSource ==========
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
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}
/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
