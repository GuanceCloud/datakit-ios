//
//  SecondViewController.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/2/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import "SecondViewController.h"
#import "ThirdViewController.h"
@interface SecondViewController ()

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"2";
    [self createUI];
    // Do any additional setup after loading the view.
}
- (void)createUI{
    UIButton *btn = [[UIButton alloc]initWithFrame:CGRectMake(50, 150, 200, 40)];
    [btn setTitle:@"前往第三页" forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor yellowColor];
    [btn addTarget:self action:@selector(btnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
}
- (void)btnClick{
    [self.navigationController pushViewController:[ThirdViewController new] animated:YES];
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
