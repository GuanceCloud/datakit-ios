//
//  DemoViewController.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "DemoViewController.h"
#import "UITestVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/FTBaseInfoHander.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
//测试崩溃采集
#import "FTUncaughtExceptionHandler+Test.h"
#import "TestANRVC.h"
#import "TestWKWebViewVC.h"
#import "CrashVC.h"
#import "TableViewCellItem.h"
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
        [[FTMobileAgent sharedInstance] bindUserWithUserID:@"user1"];
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:@"UserLogout" handler:^{
        [[FTMobileAgent sharedInstance] logout];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:@"NetworkTrace_clienthttp" handler:^{
        NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        }];
    }];
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:@"NetworkTrace_webview" handler:^{
        [weakSelf.navigationController pushViewController:[TestWKWebViewVC new] animated:YES];
    }];
    TableViewCellItem *item6 = [[TableViewCellItem alloc]initWithTitle:@"TraceConsoleLog" handler:^{
        NSLog(@"Test_traceConsoleLog");
    }];
    TableViewCellItem *item7 = [[TableViewCellItem alloc]initWithTitle:@"TrackAppFreezeAndANR" handler:^{
        [weakSelf.navigationController pushViewController:[TestANRVC new] animated:YES];
    }];
    TableViewCellItem *item8 = [[TableViewCellItem alloc]initWithTitle:@"TrackAppCrash" handler:^{
        [weakSelf.navigationController pushViewController:[CrashVC new] animated:YES];
    }];
 
    [self.dataSource addObjectsFromArray:@[item1,item2,item3,item4,item5,item6,item7,item8]];
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
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    TableViewCellItem *item = self.dataSource[indexPath.row];
    if (item.handler) {
        item.handler();
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.tabBarController.tabBar.hidden = NO;
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.tabBarController.tabBar.hidden = YES;
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
