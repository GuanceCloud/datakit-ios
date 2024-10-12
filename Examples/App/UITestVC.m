//
//  UITestVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/12/20.
//  Copyright © 2019 hll. All rights reserved.
//

#import "UITestVC.h"
#import "AppDelegate.h"
@interface UITestVC ()<UICollectionViewDelegate,UICollectionViewDataSource>
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
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
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tap)];
    [_scrollView addGestureRecognizer:tap];
    _segmentedControl.frame = CGRectMake(100, 0, 100, 40);
    _segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"first", @"second", @"third"]];
    [_segmentedControl addTarget:self action:@selector(segmentedAction:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_segmentedControl];
    _firstButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _firstButton.frame = CGRectMake(x, 40, 100, 30);
    [_firstButton setTitle:@"ActivityStart" forState:UIControlStateNormal];
    _firstButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [_firstButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [_firstButton addTarget:self action:@selector(firstAction:) forControlEvents:UIControlEventTouchUpInside];
    _firstButton.isAccessibilityElement = YES;
    _firstButton.layer.borderWidth = 1;
    _firstButton.layer.borderColor = [UIColor grayColor].CGColor;
    [_scrollView addSubview:_firstButton];
  
    
    y = CGRectGetMaxY(_firstButton.frame) + 22;
    _secondButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _secondButton.frame = CGRectMake(x, y, 100, 30);
    [_secondButton setTitle:@"ActivityEnd" forState:UIControlStateNormal];
    [_secondButton addTarget:self action:@selector(secondAction:) forControlEvents:UIControlEventTouchUpInside];
    _secondButton.isAccessibilityElement = YES;
    [_scrollView addSubview:_secondButton];
    UITextField *text = [[UITextField alloc]initWithFrame:CGRectMake(x+200, 40, 100, 30)];
    text.backgroundColor = [UIColor grayColor];
    [_scrollView addSubview:text];
    _textField = text;
    y = CGRectGetMaxY(_secondButton.frame) + 16;
    _stepper = [[UIStepper alloc] initWithFrame:CGRectMake(x, y, 80, 40)];
    [_stepper addTarget:self action:@selector(stepperAction:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_stepper];
    
    _uiswitch = [[UISwitch alloc] init];
    _uiswitch.frame = CGRectMake(CGRectGetMaxX(_stepper.frame)+30, y, 80, 40);
    [_uiswitch addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_uiswitch];
    
    _slider = [[UISlider alloc]init];
    _slider.frame = CGRectMake(CGRectGetMaxX(_uiswitch.frame)+30, y, 120, 40);
    _slider.minimumValue = 0;
    _slider.maximumValue = 10;
    _slider.value = 5;
    [_scrollView addSubview:_slider];
    
    _progressView = [[UIProgressView alloc]init];
    _progressView.frame = CGRectMake(CGRectGetMaxX(_uiswitch.frame)+30, y-40, 120, 20);
    _progressView.progress = 0.5;
    [_scrollView addSubview:_progressView];
    CGRect frame = CGRectMake(CGRectGetMaxX(_segmentedControl.frame), 0, 0, 40);
    // 创建 UIDatePicker 对象
    UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:frame];
    // 设置日期选择器模式:日期模式
    datePicker.datePickerMode = UIDatePickerModeDate;
    // 设置可供选择的最小时间：昨天
    NSTimeInterval time = 24 * 60 * 60; // 24H 的时间戳值
    datePicker.minimumDate = [[NSDate alloc] initWithTimeIntervalSinceNow:- time];
    // 设置可供选择的最大时间：明天
    datePicker.maximumDate = [[NSDate alloc] initWithTimeIntervalSinceNow:time];
    // 添加 Target-Action
    [datePicker addTarget:self
                   action:@selector(datePickerValueChanged:)
         forControlEvents:UIControlEventValueChanged];
    // 将 UIDatePicker 对象添加到当前视图
    [_scrollView addSubview:datePicker];
    y = CGRectGetMaxY(_uiswitch.frame) + 20;
    _label = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, 50)];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.backgroundColor = [UIColor orangeColor];
    _label.text = @"label";
    _label.userInteractionEnabled = YES;
    _label.accessibilityLabel = @"LABLE_CLICK";
    _label.isAccessibilityElement = YES;
    [_scrollView addSubview:_label];
    
    y = CGRectGetMaxY(_label.frame) + 10;
    _imageView = [[UIImageView alloc] init];
    _imageView.userInteractionEnabled = YES;
    _imageView.frame = CGRectMake(x, y, width, 50);
    _imageView.backgroundColor = [UIColor lightGrayColor];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.imageView.image = [UIImage imageNamed:@"order_status_top"];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.imageView.image = nil;
    });
    _imageView.userInteractionEnabled = YES;
    _imageView.accessibilityLabel = @"IMAGE_CLICK";
    [_scrollView addSubview:_imageView];
    
    _scrollView.contentSize = CGSizeMake(0, CGRectGetMaxY(_imageView.frame) + 16);
    
    UITapGestureRecognizer *tap1 = [UITapGestureRecognizer new];
    [tap1 addTarget:self action:@selector(tap1Action:)];
    [_label addGestureRecognizer:tap1];
    
    UILongPressGestureRecognizer *tap2 = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tap2Action:)];
    
    [_imageView addGestureRecognizer:tap2];
    [self setupCollectionView];
}
- (void)setupCollectionView{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc]init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.itemSize = CGSizeMake(100, 40);
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_scrollView.frame), CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame)/2) collectionViewLayout:layout];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;

    [_collectionView registerClass:UICollectionViewCell.class forCellWithReuseIdentifier:@"UICollectionViewCell"];
    [self.view addSubview:_collectionView];
}
- (void)datePickerValueChanged:(id)sender{
    
}
- (void)firstAction:(UIButton *)sender {
    NSLog(@"%@ Touch Up Inside", sender.currentTitle);
    if (@available(iOS 13.0, *)) {
        if(!_activityIndicator){
            UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            activityIndicator.frame = CGRectMake(0, 0, 50, 50);
            
            // 设置颜色
            activityIndicator.color = [UIColor grayColor];
            
            // 设置位置
            activityIndicator.center = self.view.center;
            
            // 添加到视图
            [self.view addSubview:activityIndicator];
            _activityIndicator = activityIndicator;
        }
        [_activityIndicator startAnimating];
    }
}

- (void)secondAction:(UIButton *)sender {
    NSLog(@"%@ Touch Up Inside", sender.currentTitle);
    [self.activityIndicator stopAnimating];
}
- (void)resultAction:(UIButton *)sender{
    
}
- (void)stepperAction:(UIStepper *)sender {
    NSLog(@"UIStepper on:%f", sender.value);
    _slider.value = sender.value;
    [_progressView setProgress:_slider.value/10 animated:YES];
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
- (void)tap{
    [_textField resignFirstResponder];
}
#pragma mark -
-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 2;
}
-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return 20;
}
-(__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"UICollectionViewCell" forIndexPath:indexPath];
    UILabel *lable = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 100, 40)];
    lable.text = [NSString stringWithFormat:@"cell: %ld", indexPath.row];
    [cell.contentView addSubview:lable];
    lable.backgroundColor = [self randomColor];
    lable.accessibilityLabel =[NSString stringWithFormat:@"cell: %ld", indexPath.row];
    lable.isAccessibilityElement = YES;
    return cell;
}
-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    
}
- (UIColor *)randomColor {
    int R = (arc4random() % 256) ;
    int G = (arc4random() % 256) ;
    int B = (arc4random() % 256) ;
    return [UIColor colorWithRed:R/255.0 green:G/255.0 blue:B/255.0 alpha:1];
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
