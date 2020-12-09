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
#import "TestANRVC.h"
#import "TestWKWebViewVC.h"
@interface DemoViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSArray *dataSource;

@end

@implementation DemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.dataSource = @[@"Test_eventFlowLog",@"Test_crashLog",@"test_SIGSEGVCrash",@"test_SIGBUSCrash",@"test_CCrash",@"Test_ANR",@"Test_networkTrace_webview",@"Test_networkTrace_clienthttp"];
    [self createUI];
}
-(void)createUI{
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
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
- (void)Test_ANR{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestANRVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}
- (void)test_webview{
    self.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:[TestWKWebViewVC new] animated:YES];
    self.hidesBottomBarWhenPushed = NO;
}
- (void)test_client_http{
    NSString *urlStr = @"http://www.weather.com.cn/data/sk/101010100.html";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
    }];
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
            [self testCrashLog];
            break;
        case 2:
            [self testSIGSEGVCrash];
            break;
        case 3:
            [self testSIGBUSCrash];
            break;
        case 4:
            [self testCCrash];
            break;
        case 5:
            [self Test_ANR];
            break;
        case 6:
            [self test_webview];
            break;
        case 7:
            [self test_client_http];
            break;
        default:
            break;
    }
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
