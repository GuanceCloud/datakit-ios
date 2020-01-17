//
//  RootViewController.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "RootViewController.h"
#import "ResultVC.h"
#import "Test4ViewController.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import "UITestManger.h"

@interface RootViewController ()

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];
    self.view.backgroundColor = [UIColor whiteColor];
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 100, 100)];
    button.backgroundColor = [UIColor redColor];
    [button setTitle:@"login" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
       [self.view addSubview:button];
    UIButton *button2 = [[UIButton alloc]initWithFrame:CGRectMake(100, 300, 150, 100)];
    button2.backgroundColor = [UIColor orangeColor];
    [button2 setTitle:@"result logout" forState:UIControlStateNormal];
    [button2 addTarget:self action:@selector(endBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
}
- (void)buttonClick{
    [[FTMobileAgent sharedInstance] bindUserWithName:@"123" Id:@"1111111" exts:nil];
    [[UITestManger sharedManger] addAutoTrackClickCount];
    [self.navigationController pushViewController:[Test4ViewController new] animated:YES];
}
-(void)endBtnClick{
//    [[FTMobileAgent sharedInstance] logout];
    [[UITestManger sharedManger] addAutoTrackClickCount];
    [self.navigationController pushViewController:[ResultVC new] animated:YES];
}
-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
}
-(void)dealloc{
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];
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
