//
//  UITestVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/12/20.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UITestVC.h"
#import "AppDelegate.h"
#import "ResultVC.h"
@interface UITestVC ()<UITableViewDelegate,UITableViewDataSource>

@end

@implementation UITestVC
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self createUI];
}
-(void)createUI{
    CGFloat x = 16;
    CGFloat y = 16;
    CGFloat width = self.view.frame.size.width - 2 * x;
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame)/2)];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_scrollView];
    
    _firstButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _firstButton.frame = CGRectMake(x, 26, 100, 44);
    [_firstButton setTitle:@"FirstButton" forState:UIControlStateNormal];
    [_firstButton setTitle:@"SelectedFirstButton" forState:UIControlStateSelected];
    [_firstButton addTarget:self action:@selector(firstAction:) forControlEvents:UIControlEventTouchUpInside];
    _firstButton.isAccessibilityElement = YES;
    [_scrollView addSubview:_firstButton];
    UIButton *result = [UIButton buttonWithType:UIButtonTypeCustom];
    result.frame = CGRectMake(width-100, 26, 100, 44);
    [result setTitle:@"result" forState:UIControlStateNormal];
    [result setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [result addTarget:self action:@selector(resultAction:) forControlEvents:UIControlEventTouchUpInside];
//    result.accessibilityLabel = @"NEXT_CLICK";
//    result.isAccessibilityElement = YES;
    [self.scrollView addSubview:result];
    
    y = CGRectGetMaxY(_firstButton.frame) + 16;
    _secondButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _secondButton.frame = CGRectMake(x, y, 100, 44);
    [_secondButton setTitle:@"SecondButton" forState:UIControlStateNormal];
    [_secondButton setTitle:@"SelectedSecondButton" forState:UIControlStateSelected];
    [_secondButton addTarget:self action:@selector(secondAction:) forControlEvents:UIControlEventTouchUpInside];
    _secondButton.isAccessibilityElement = YES;
    [_scrollView addSubview:_secondButton];
    UITextField *text = [[UITextField alloc]initWithFrame:CGRectMake(x+200, y, 100, 44)];
    text.backgroundColor = [UIColor grayColor];
    [_scrollView addSubview:text];
    y = CGRectGetMaxY(_secondButton.frame) + 16;
    _stepper = [[UIStepper alloc] initWithFrame:CGRectMake(x, y, 80, 40)];
    [_stepper addTarget:self action:@selector(stepperAction:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_stepper];
    
    
    
    _uiswitch = [[UISwitch alloc] init];
    _uiswitch.frame = CGRectMake(CGRectGetMaxX(_stepper.frame)+50, y, 80, 40);
    [_uiswitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_uiswitch];
    
    _segmentedControl.frame = CGRectMake(100, 100, 100, 40);
    _segmentedControl.backgroundColor = [UIColor blueColor];
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"first", @"second", @"third"]];
    [_segmentedControl addTarget:self action:@selector(segmentedAction:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_segmentedControl];
    
    y = CGRectGetMaxY(_uiswitch.frame) + 20;
    _label = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, 50)];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.backgroundColor = [UIColor orangeColor];
    _label.text = @"lable";
    _label.userInteractionEnabled = YES;
    _label.accessibilityLabel = @"LABLE_CLICK";
    _label.isAccessibilityElement = YES;
    [_scrollView addSubview:_label];
    
    y = CGRectGetMaxY(_label.frame) + 10;
    _imageView = [[UIImageView alloc] init];
    _imageView.userInteractionEnabled = YES;
    _imageView.frame = CGRectMake(x, y, width, 50);
    _imageView.backgroundColor = [UIColor lightGrayColor];
    _imageView.image = [UIImage imageNamed:@"order_status_top"];
    _imageView.userInteractionEnabled = YES;
    _imageView.accessibilityLabel = @"IMAGE_CLICK";
    [_scrollView addSubview:_imageView];
    
    _scrollView.contentSize = CGSizeMake(0, CGRectGetMaxY(_imageView.frame) + 16);
    
    UITapGestureRecognizer *tap1 = [UITapGestureRecognizer new];
    [tap1 addTarget:self action:@selector(tap1Action:)];
    [_label addGestureRecognizer:tap1];
    
    UILongPressGestureRecognizer *tap2 = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tap2Action:)];
    
    [_imageView addGestureRecognizer:tap2];
    
    [self setupTableView];
    
    
}
- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_scrollView.frame), CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame)/2)];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];
    
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
}

- (void)firstAction:(UIButton *)sender {
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试" message:@"测试alert按钮点击" preferredStyle:UIAlertControllerStyleAlert];
//    UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//        NSLog(@"点击OK");
//    }];
//    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"CANCEL" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
//        NSLog(@"点击CANCEL");
//    }];
//    [alert addAction:action];
//    [alert addAction:cancel];
//    [self presentViewController:alert animated:YES completion:nil];
    NSLog(@"%@ Touch Up Inside", sender.currentTitle);

}

- (void)secondAction:(UIButton *)sender {
    NSLog(@"%@ Touch Up Inside", sender.currentTitle);
}
- (void)resultAction:(UIButton *)sender{
    
    [self.navigationController pushViewController:[ResultVC new] animated:YES];
}
- (void)stepperAction:(UIStepper *)sender {
    NSLog(@"UIStepper on:%f", sender.value);
}

- (void)switchAction:(UISwitch *)sender {
    NSLog(@"UISwitch on:%d", sender.isOn);
}

- (void)segmentedAction:(UISegmentedControl *)sender {
    NSLog(@"UISwitch on:%ld", sender.selectedSegmentIndex);
}

- (void)labelTouchUpInside:(UITapGestureRecognizer *)recognizer {
    UILabel *label = (UILabel *)recognizer.view;
    NSLog(@"%@被点击了", label.text);
}
- (void)tap1Action:(UIGestureRecognizer *)sender {
    UILabel *label = (UILabel *)sender.view;
    NSLog(@"%@被点击了", label.text);
}

- (void)tap2Action:(UIGestureRecognizer *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Long Press" message:@"press!" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil];
    cancel.accessibilityLabel = @"alert cancel";
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
    NSLog(@"UIImageView被点击了");
}
#pragma mark -
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 20;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"Section: %ld, Row: %ld", indexPath.section, indexPath.row];
    cell.accessibilityLabel =[NSString stringWithFormat:@"Row: %ld", indexPath.row];
    cell.isAccessibilityElement = YES;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"%@", indexPath);
    
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
