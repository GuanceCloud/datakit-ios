//
//  TestFlowTrackVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/2/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestFlowTrackVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
@interface TestFlowTrackVC ()
@property (nonatomic, assign)  long preTime;
@property (nonatomic, copy)  NSString *traceId;
@end

@implementation TestFlowTrackVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"测试流程图";
    [self createUI];
    // Do any additional setup after loading the view.
}
- (void)createUI{
    UILabel *lab = [[UILabel alloc]initWithFrame:CGRectMake(50, 150, 400, 40)];
    lab.text = @"请按照[节点1] ->[节点2] -> [节点3] 顺序点击";
    [self.view addSubview:lab];
    UIButton *btn1 = [[UIButton alloc]initWithFrame:CGRectMake(50, 200, 200, 40)];
    [btn1 setTitle:@"节点1" forState:UIControlStateNormal];
    btn1.backgroundColor = [UIColor orangeColor];
    [btn1 setTitleColor:[UIColor redColor] forState:UIControlStateHighlighted];
    [btn1 addTarget:self action:@selector(btnClick1) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn1];
    UIButton *btn2 = [[UIButton alloc]initWithFrame:CGRectMake(50, 300, 200, 40)];
    [btn2 setTitle:@"节点2" forState:UIControlStateNormal];
    btn2.backgroundColor = [UIColor grayColor];
    [btn2 setTitleColor:[UIColor redColor] forState:UIControlStateHighlighted];
    [btn2 addTarget:self action:@selector(btnClick2) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn2];
    UIButton *btn3 = [[UIButton alloc]initWithFrame:CGRectMake(50, 400, 200, 40)];
    [btn3 setTitle:@"节点3" forState:UIControlStateNormal];
    btn3.backgroundColor = [UIColor purpleColor];
    [btn3 setTitleColor:[UIColor redColor] forState:UIControlStateHighlighted];
    [btn3 addTarget:self action:@selector(btnClick3) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn3];
    self.traceId =[NSString stringWithFormat:@"trace%@",[[NSUUID UUID] UUIDString]] ;
}
- (void)btnClick1{
    
    [[FTMobileAgent sharedInstance] flowTrack:@"track_flow" traceId:self.traceId name:@"流程图节点1" parent:nil duration:0];
    NSDate *datenow = [NSDate date];
    long time= (long)([datenow timeIntervalSince1970]*1000);
    self.preTime = time;
}
- (void)btnClick2{
    NSDate *datenow = [NSDate date];
    long time= (long)([datenow timeIntervalSince1970]*1000);
    long duration = time-self.preTime;
    self.preTime = time;
    [[FTMobileAgent sharedInstance] flowTrack:@"track_flow" traceId:self.traceId name:@"流程图节点2" parent:@"流程图节点1" tags:nil duration:duration field:@{@"event":@"flow"}];    
}
- (void)btnClick3{
    NSDate *datenow = [NSDate date];
    long time= (long)([datenow timeIntervalSince1970]*1000);
    long duration = time-self.preTime;
    self.preTime = time;
    [[FTMobileAgent sharedInstance] flowTrack:@"track_flow" traceId:self.traceId name:@"流程图节点3" parent:@"流程图节点2" duration:duration];
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
