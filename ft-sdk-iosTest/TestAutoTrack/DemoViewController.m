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
#import "TestBluetoothList.h"
#import "TestCustomTrackVC.h"
#import "ft_sdk_iosTest-Swift.h"
#import <FTMobileAgent/FTBaseInfoHander.h>
@interface DemoViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSArray *dataSource;

@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *rightBarItem = [[UIBarButtonItem alloc] initWithTitle:@"确认" style:UIBarButtonItemStylePlain target:self action:@selector(onClickedOKbtn)];
    self.navigationItem.rightBarButtonItem = rightBarItem;
    self.dataSource = @[@"BindUser",@"LogOut",@"Test_CustomTrack",@"Test_flowTrack",@"Test_autoTrack",@"Test_subFlowTrack",@"Test_subFlowTrack2",@"Test_resetConfig",@"Test_startLocation",@"Test_startMonitorFlush",@"Test_stopMonitorFlush",@"Test_getConnectBluetooth",@"Test_addPageDesc",@"Test_addVtpDesc",@"Test_crashLog",@"Test_log",@"Test_NetworkTrace"];
    [self createUI];
}
- (void)onClickedOKbtn {
    NSLog(@"onClickedOKbtn");
}  
-(void)createUI{
    
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    _mtableView.vtpAddIndexPath = YES;
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
- (void)testCustomTrack{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestCustomTrackVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
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
    NSString *token = [processInfo environment][@"ACCESS_DATAWAY_TOKEN"];

    // 新的config 关闭了autoTrack  将无全埋点日志
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:url datawayToken:token akId:akId akSecret:akSecret enableRequestSigning:YES];
    config.enableLog = YES;
    config.enableAutoTrack = NO;
    [config setEnableScreenFlow:NO];
    [FTMobileAgent startWithConfigOptions:config];
}
- (void)testStartMonitorFlush{
    [[FTMobileAgent sharedInstance] startMonitorFlushWithInterval:10 monitorType:FTMonitorInfoTypeAll];
}
- (void)testStopMonitorFlush{
    [[FTMobileAgent sharedInstance] stopMonitorFlush];
}
- (void)testAddPageDesc{
    NSDictionary *dict = @{@"DemoViewController":@"首页",
                                  @"RootTabbarVC":@"底部导航",
                                  @"UITestVC":@"UI测试",
                                  @"ResultVC":@"测试结果",
           };
    [[FTMobileAgent sharedInstance] addPageDescDict:dict];
    [[FTMobileAgent sharedInstance] isFlowChartDescEnabled:YES];
    [[FTMobileAgent sharedInstance] isPageVtpDescEnabled:YES];
}
- (void)testConnectBluetooth{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestBluetoothList new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}
- (void)testAddVtpDesc{
    NSDictionary *vtpdict = @{@"UITabBarController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITabBar/UITabBarButton[2]":@"second点击",
                              @"UITabBarController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITabBar/UITabBarButton[1]":@"home点击",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationBar/_UINavigationBarContentView/_UIButtonBarStackView/_UIButtonBarButton[0]":@"导航确认点击",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[0]":@"测试绑定用户",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[1]":@"测试登出用户",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[2]":@"测试主动埋点",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[3]":@"测试主动埋点立即上传",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[4]":@"测试主动埋点立即上传多条",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[5]":@"测试流程图",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[6]":@"测试全埋点",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[7]":@"测试子页面流程图1",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[8]":@"测试子页面流程图2",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[9]":@"测试重置config",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[10]":@"测试获取地理位置信息",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[11]":@"测试监控项周期上传开启",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[12]":@"测试监控项周期上传关闭",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[13]":@"测试添加页面描述",
                              @"DemoViewController/UIWindow/UITransitionView/UIDropShadowView/UILayoutContainerView/UITransitionView/UIViewControllerWrapperView/UILayoutContainerView/UINavigationTransitionView/UIViewControllerWrapperView/UIView/UITableView[0]/section[0]/row[14]":@"测试添加视图树描述",

    };
    [[FTMobileAgent sharedInstance] addVtpDescDict:vtpdict];
    [[FTMobileAgent sharedInstance] isPageVtpDescEnabled:YES];
    
}
- (void)testCrashLog{
    NSString *value = nil;
    NSDictionary *dict = @{@"11":value};
}
- (void)testLog{
    NSLog(@"testLog");
    FrintHookTest *test = [[FrintHookTest alloc]init];
    [test show];
}
- (void)testNetworkTrace{
    NSArray *search = @[@"上海天气",@"鹅鹅鹅",@"温度",@"机器人"];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    int x = arc4random() % 4;
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",search[x]];
    NSString *urlStr = @"http://api.qingyunke.com/api.php";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];

    request.HTTPMethod = @"POST";
    [request addValue:[FTBaseInfoHander ft_currentGMT] forHTTPHeaderField:@"Date"];
    [request addValue:[FTBaseInfoHander ft_currentGMT] forHTTPHeaderField:@"Date"];

    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *res =(NSHTTPURLResponse *)response;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:[NSString stringWithFormat:@"statusCode == %ld",(long)res.statusCode]];
        });
    }];
    [task resume];
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
            [self testCustomTrack];
            break;
        case 3:
            [self testFlowTrack];
            break;
        case 4:
            [self testAutoTrack];
            break;
        case 5:
            [self testSubFlowTrack];
            break;
        case 6:
            [self testSubFlowTrack2];
            break;
        case 7:
            [self testResetConfig];
            break;
        case 8:
            [self testStartLocation];
            break;
        case 9:
            [self testStartMonitorFlush];
            break;
        case 10:
            [self testStopMonitorFlush];
            break;
        case 11:
            [self testConnectBluetooth];
            break;
        case 12:
            [self testAddPageDesc];
            break;
        case 13:
            [self testAddVtpDesc];
            break;
        case 14:
            [self testCrashLog];
            break;
        case 15:
            [self testLog];
            break;
        case 16:
            [self testNetworkTrace];
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
