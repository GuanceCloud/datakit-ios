//
//  SecondViewController.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "SecondViewController.h"
#import "Test4ViewController.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import "AutoTrackManger.h"
@interface SecondViewController ()

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[AutoTrackManger sharedManger] addAutoTrackViewScreenCount];

    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor greenColor];
    [self createUI];
}
- (void)createUI{
    NSArray *array = [[AutoTrackManger sharedManger] getEndResult];
    for (NSInteger i=0; i<array.count; i++) {
        UILabel *lab = [[UILabel alloc]initWithFrame:CGRectMake(10, 100, 100, 50+i*100)];
        lab.text = array[i];
        lab.backgroundColor = [UIColor redColor];
        [self.view addSubview:lab];
    }
    
}
-(void)dealloc{
    [[AutoTrackManger sharedManger] addAutoTrackViewScreenCount];
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
