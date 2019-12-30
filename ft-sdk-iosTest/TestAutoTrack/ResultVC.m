//
//  SecondViewController.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ResultVC.h"
#import "Test4ViewController.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTMobileAgent/ZYDataBase/ZYTrackerEventDBTool.h>
#import "UITestManger.h"
@interface ResultVC ()

@end

@implementation ResultVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];

    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor greenColor];
    [self createUI];
}
- (void)createUI{
    NSArray *array = [[UITestManger sharedManger] getEndResult];
    for (NSInteger i=0; i<array.count; i++) {
        UILabel *lab = [[UILabel alloc]initWithFrame:CGRectMake(10, 100, 100, 50+i*100)];
        lab.text = array[i];
        lab.backgroundColor = [UIColor redColor];
        [self.view addSubview:lab];
    }
    
    UILabel *lable = [[UILabel alloc]initWithFrame:CGRectMake(10, 300, 300, 200)];
    lable.backgroundColor = [UIColor whiteColor];
    lable.numberOfLines = 0;
    lable.text = [NSString stringWithFormat:@"数据库原有数据 %ld 条\n 数据库增加：\nlunch:1\nopen、close：%ld \nclick:%ld \n数据库现有数据： %ld 条",[UITestManger sharedManger].lastCount,[UITestManger sharedManger].autoTrackViewScreenCount,[UITestManger sharedManger].autoTrackClickCount,[[ZYTrackerEventDBTool sharedManger] getDatasCount]];
    [self.view addSubview:lable];
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
