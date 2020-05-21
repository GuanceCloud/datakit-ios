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
    UIBarButtonItem *rightBarItem = [[UIBarButtonItem alloc] initWithTitle:@"确认" style:UIBarButtonItemStylePlain target:self action:@selector(onClickedOKbtn)];
    self.navigationItem.rightBarButtonItem = rightBarItem;
    self.dataSource = @[@"BindUser",@"LogOut",@"Test_trackBackgroud",@"Test_trackImmediate",@"Test_trackImmediateList",@"Test_flowTrack",@"Test_autoTrack",@"Test_subFlowTrack",@"Test_subFlowTrack2",@"Test_resetConfig",@"Test_startLocation",@"Test_startMonitorFlush",@"Test_stopMonitorFlush",@"Test_addPageDesc",@"Test_addVtpDesc"];
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
        case 13:
            [self testAddPageDesc];
            break;
        case 14:
            [self testAddVtpDesc];
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
