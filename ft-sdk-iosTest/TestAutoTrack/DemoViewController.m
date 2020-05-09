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
#import "UITestManger.h"
#import "AppDelegate.h"
#import "TestFlowTrackVC.h"
#import "TestSubFlowTrack.h"
#import "TestSubFlowTrack2.h"

@interface DemoViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSArray *dataSource;
@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.dataSource = @[@"BindUser",@"LogOut",@"Test_trackBackgroud",@"Test_trackImmediate",@"Test_trackImmediateList",@"Test_flowTrack",@"Test_autoTrack",@"Test_subFlowTrack",@"Test_subFlowTrack2",@"Test_resetConfig",@"Test_startLocation",@"Test_startMonitorFlush",@"Test_stopMonitorFlush"];
    [self createUI];
}
-(void)createUI{
    
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    [self.view addSubview:_mtableView];
    
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
}
- (void)testStartLocation{
    dispatch_async(dispatch_get_main_queue(), ^{
        [FTMobileAgent startLocation:^(NSInteger errorCode, NSString * _Nullable errorMessage) {
        
            [self showResult:[NSString stringWithFormat:@"errorCode = %ld,errorMessage=%@",(long)errorCode,errorMessage]];
        }];
    });
    
}
- (void)testBindUser{
    [[FTMobileAgent sharedInstance] bindUserWithName:@"test8" Id:@"1111111" exts:@{@"platform": @"ios"}];
}
- (void)testUserLogout{
    [[FTMobileAgent sharedInstance] logout];
}
- (void)testTrackBackgroud{
    [[FTMobileAgent sharedInstance] trackBackground:@"track ,Test" tags:nil field:@{@"ev，ent":@"te s，t"}];
}
- (void)testTrackImmediate{
    [[FTMobileAgent sharedInstance] trackImmediate:@"testImmediateList" field:@{@"test":@"testImmediate"} callBack:^(NSInteger statusCode, id  _Nonnull responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
}
- (void)testTrackImmediateList{
    //bean1 用户自己传时间  bean2 自动赋值
    FTTrackBean *bean1 = [FTTrackBean new];
    bean1.measurement = @"testImmediateList";
    bean1.field =@{@"test":@"testImmediateList"};
    NSDate *datenow = [NSDate date];
    long time= (long)([datenow timeIntervalSince1970]*1000);
    bean1.timeMillis =time;
    FTTrackBean *bean2 = [FTTrackBean new];
    bean2.measurement = @"testImmediateList2";
    bean2.field =@{@"test":@"testImmediateList2"};
    
    [[FTMobileAgent sharedInstance] trackImmediateList:@[bean1,bean2] callBack:^(NSInteger statusCode, id  _Nonnull responseObject) {
        NSLog(@"responseObject = %@",responseObject);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
    
}
- (void)testFlowTrack{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestFlowTrackVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
    
}
- (void)testAutoTrack{
    
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[UITestVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}
- (void)testSubFlowTrack{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestSubFlowTrack new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
    
}
- (void)testSubFlowTrack2{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestSubFlowTrack2 new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}
-(void)showResult:(NSString *)title{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *commit = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:commit];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)testResetConfig{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *akId =[processInfo environment][@"ACCESS_KEY_ID"];
    NSString *akSecret = [processInfo environment][@"ACCESS_KEY_SECRET"];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    // 新的config 关闭了autoTrack  将无全埋点日志
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url akId:akId akSecret:akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = NO;
    [config enableTrackScreenFlow:NO];
    [FTMobileAgent startWithConfigOptions:config];
}
- (void)testStartMonitorFlush{
    [[FTMobileAgent sharedInstance] startMonitorFlushWithInterval:10 monitorType:FTMonitorInfoTypeAll];
}
- (void)testStopMonitorFlush{
    [[FTMobileAgent sharedInstance] stopMonitorFlush];
}
#pragma mark ========== UITableViewDataSource ==========
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.textLabel.text = self.dataSource[indexPath.row];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSUInteger row = [indexPath row];
    switch (row) {
        case 0:
            [self testBindUser];
            break;
        case 1:
            [self testUserLogout];
            break;
        case 2:
            [self testTrackBackgroud];
            break;
        case 3:
            [self testTrackImmediate];
            break;
        case 4:
            [self testTrackImmediateList];
            break;
        case 5:
            [self testFlowTrack];
            break;
        case 6:
            [self testAutoTrack];
            break;
        case 7:
            [self testSubFlowTrack];
            break;
        case 8:
            [self testSubFlowTrack2];
            break;
        case 9:
            [self testResetConfig];
            break;
        case 10:
            [self testStartLocation];
            break;
        case 11:
            [self testStartMonitorFlush];
            break;
        case 12:
            [self testStopMonitorFlush];
            break;
        default:
            break;
    }
    [[UITestManger sharedManger] addAutoTrackClickCount];
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
