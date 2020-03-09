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
    self.dataSource = @[@"BindUser",@"LogOut",@"Test_trackBackgroud",@"Test_trackImmediate",@"Test_flowTrack",@"Test_autoTrack",@"Test_subFlowTrack",@"Test_subFlowTrack2"];
    [self createUI];
}
-(void)createUI{
    
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, 400)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    [self.view addSubview:_mtableView];
    
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
}

- (void)testBindUser{
    [[FTMobileAgent sharedInstance] bindUserWithName:@"test8" Id:@"1111111" exts:nil];
}
- (void)testUserLogout{
    [[FTMobileAgent sharedInstance] logout];
}
- (void)testTrackBackgroud{
    [[FTMobileAgent sharedInstance] trackBackgroud:@"trackTest" tags:nil values:@{@"event":@"test"}];
}
- (void)testTrackImmediate{
    [[FTMobileAgent sharedInstance] trackImmediate:@"testImmediate" values:@{@"test":@"testImmediate"} callBack:^(BOOL isSuccess) {
        NSLog(@"success = %d",isSuccess);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:isSuccess?@"success":@"fail"];
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
            [self testFlowTrack];
            break;
        case 5:
            [self testAutoTrack];
            break;
        case 6:
            [self testSubFlowTrack];
        case 7:
            [self testSubFlowTrack2];
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
