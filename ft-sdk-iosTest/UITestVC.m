//
//  UITestVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/12/20.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UITestVC.h"
@interface UITestVC ()
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UIStepper *stepper;
@property (nonatomic, strong) UISwitch *uiswitch;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UIScrollView *scrollView;
@end

@implementation UITestVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self createUI];
}
-(void)createUI{
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(40, 20, 100, 40)];
    button.backgroundColor = [UIColor redColor];
    [self.view addSubview:button];
   
    UISwitch *swi = [[UISwitch alloc]initWithFrame:CGRectMake(40, 100, 100, 40)];
    swi.backgroundColor = [UIColor yellowColor];
    [self.view addSubview:swi];
    
    UITextField *tf = [[UITextField alloc]initWithFrame:CGRectMake(40, 160, 100, 40)];
    [self.view addSubview:tf];
    
    UIToolbar *tool = [[UIToolbar alloc]initWithFrame:CGRectMake(40, 220, 100, 40)];
    tool.backgroundColor = [UIColor greenColor];
    [self.view addSubview:tool];
    
    
    
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
