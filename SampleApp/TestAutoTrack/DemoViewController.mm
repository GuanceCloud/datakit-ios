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
#import "TestBluetoothList.h"
#import <FTMobileAgent/FTBaseInfoHander.h>
#import <FTMobileAgent/NSDate+FTAdd.h>
//测试崩溃采集
#import "FTUncaughtExceptionHandler+Test.h"
#import "TestCCrash.hpp"
#import "TestWKWebViewVC.h"
#import "TestANRVC.h"
@interface DemoViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSArray *dataSource;

@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *rightBarItem = [[UIBarButtonItem alloc] initWithTitle:@"确认" style:UIBarButtonItemStylePlain target:self action:@selector(onClickedOKbtn)];
    self.navigationItem.rightBarButtonItem = rightBarItem;
    self.dataSource = @[@"Test_autoTrack",@"Test_startMonitorFlush",@"Test_stopMonitorFlush",@"Test_getConnectBluetooth",@"Test_crashLog",@"test_SIGSEGVCrash",@"test_SIGBUSCrash",@"test_CCrash",@"test_webview",@"Test_ANR"];
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
- (void)testAutoTrack{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[UITestVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}
-(void)showResult:(NSString *)title{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *commit = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:commit];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)testStartMonitorFlush{
    [[FTMobileAgent sharedInstance] startMonitorFlushWithInterval:10 monitorType:FTMonitorInfoTypeAll];
}
- (void)testStopMonitorFlush{
    [[FTMobileAgent sharedInstance] stopMonitorFlush];
}
- (void)testConnectBluetooth{
    NSString *uuid = [NSUUID UUID].UUIDString;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSString *parameters = [NSString stringWithFormat:@"key=free&appid=0&msg=%@",uuid];
    NSString *urlStr = @"http://api.qingyunke.com/api.php";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    request.HTTPMethod = @"POST";
    
    request.HTTPBody = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    }];
    
    [task resume];

    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestBluetoothList new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}

- (void)testCrashLog{
    //在子线程测试崩溃时 crash alert才能显示出来
    [FTUncaughtExceptionHandler sharedHandler];//仅测试崩溃使用
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *value = nil;
        NSDictionary *dict = @{@"11":value};
    });
}
/**
 *SignalHandler不要在debug环境下测试。因为系统的debug会优先去拦截。在模拟器上运行一次后，关闭debug状态，然后直接在模拟器上点击我们build上去的app去运行
 */
- (void)testSIGSEGVCrash{
    
    [FTUncaughtExceptionHandler sharedHandler];//仅测试崩溃使用
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id x_id = [self performSelector:@selector(createNum)];
    });
}
/**
 *SignalHandler不要在debug环境下测试。因为系统的debug会优先去拦截。在模拟器上运行一次后，关闭debug状态，然后直接在模拟器上点击我们build上去的app去运行
 */
- (void)testSIGBUSCrash{
    [FTUncaughtExceptionHandler sharedHandler];//仅测试崩溃使用
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char *s = "hello world";
        *s = 'H';
    });
}
- (int)createNum {
    return 10;
}
- (void)testCCrash{
    [FTUncaughtExceptionHandler sharedHandler];//仅测试崩溃使用
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        MyCppClass::testCrash();
    });
}
- (void)test_webview{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestWKWebViewVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}
- (void)Test_ANR{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestANRVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
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
            [self testAutoTrack];
            break;
        case 1:
            [self testStartMonitorFlush];
            break;
        case 2:
            [self testStopMonitorFlush];
            break;
        case 3:
            [self testConnectBluetooth];
            break;
        case 4:
            [self testCrashLog];
            break;
        case 5:
            [self testSIGSEGVCrash];
            break;
        case 6:
            [self testSIGBUSCrash];
            break;
        case 7:
            [self testCCrash];
            break;
        case 8:
            [self test_webview];
            break;
        case 9:
            [self Test_ANR];
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
