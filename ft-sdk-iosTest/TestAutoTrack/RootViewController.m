//
//  RootViewController.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "RootViewController.h"
#import "ResultVC.h"
#import "UITestVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import "UITestManger.h"
#import "AppDelegate.h"
#import <FTMobileAgent/FTDataBase/FTTrackerEventDBTool.h>
#import "AppDelegate.h"
#import "SecondViewController.h"
#define kWidth [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
@interface RootViewController ()
@property (nonatomic, strong) UITextField *tf ;
@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(50, 100, 100, 100)];
    button.backgroundColor = [UIColor redColor];
    [button setTitle:@"start" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
       [self.view addSubview:button];
    UIButton *button2 = [[UIButton alloc]initWithFrame:CGRectMake(50, 300, 150, 100)];
    button2.backgroundColor = [UIColor orangeColor];
    [button2 setTitle:@"result logout" forState:UIControlStateNormal];
    [button2 addTarget:self action:@selector(endBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    self.tf = [[UITextField alloc]initWithFrame:CGRectMake(50, 450, 300, 20)];
    self.tf.backgroundColor = [UIColor grayColor];
    [self.view addSubview:self.tf];
    
    UIButton *button3 = [[UIButton alloc]initWithFrame:CGRectMake(200, 100, 100, 100)];
    button3.backgroundColor = [UIColor redColor];
    [button3 setTitle:@"前往第二页" forState:UIControlStateNormal];
    [button3 addTarget:self action:@selector(buttonClick3) forControlEvents:UIControlEventTouchUpInside];
       [self.view addSubview:button3];
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if ([self isAutoTrackVC]) {
           [[UITestManger sharedManger] addAutoTrackViewScreenCount];
       }
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self.tf resignFirstResponder];
}
- (void)buttonClick{
   [[FTMobileAgent sharedInstance] bindUserWithName:@"test8" Id:@"1111111" exts:nil];
    if ([self isAutoTrackVC] && [self isAutoTrackUI:UIButton.class]) {
       [[UITestManger sharedManger] addAutoTrackClickCount];
        }
    [self.navigationController pushViewController:[UITestVC new] animated:YES];
}
-(void)endBtnClick{
    if ([self isAutoTrackVC] && [self isAutoTrackUI:UIButton.class]) {
    [[UITestManger sharedManger] addAutoTrackClickCount];
    }
    [self.navigationController pushViewController:[ResultVC new] animated:YES];
}
- (void)buttonClick3{
    [[FTMobileAgent sharedInstance] trackBackgroud:@"testBackground" values:@{@"test":@"testBackground"}];
    [[FTMobileAgent sharedInstance] trackImmediate:@"testImmediate" values:@{@"test":@"testImmediate"} callBack:^(BOOL isSuccess) {
           NSLog(@"success = %d",isSuccess);
       }];
    [self.navigationController pushViewController:[SecondViewController new] animated:YES];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];

}

- (BOOL)isAutoTrackUI:(Class )view{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
   
    if (appDelegate.config.whiteViewClass.count>0) {
        [appDelegate.config.whiteViewClass containsObject:view];
    }
    if(appDelegate.config.blackViewClass.count>0)
        return ! [appDelegate.config.blackViewClass containsObject:view];;
    return YES;
}
- (BOOL)isAutoTrackVC{
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (!appDelegate.config.enableAutoTrack) {
        return NO;
    }
     if (appDelegate.config.whiteVCList.count>0) {
         [appDelegate.config.whiteVCList containsObject:@"RootViewController"];
     }
     if(appDelegate.config.blackVCList.count>0)
         return ! [appDelegate.config.blackVCList containsObject:@"RootViewController"];;
     return YES;
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
