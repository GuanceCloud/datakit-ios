//
//  TestUIControlVC.m
//  App
//
//  Created by hulilei on 2024/7/29.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "TestUIControlVC.h"
#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

#define PICKER_HEIGHT   266
@interface TestUIControlVC ()<UIPickerViewDataSource, UIPickerViewDelegate>{
    NSInteger _provinceIndex;   // 省份选择 记录
    NSInteger _cityIndex;       // 市选择 记录
    NSInteger _districtIndex;   // 区选择 记录
}
@property (strong, nonatomic) UILabel *nameSelectLabel;
@property (nonatomic, strong) UIPickerView * pickerView;
@property (nonatomic, strong) UIButton * button;
@property (nonatomic, strong) UITextView *textView;
/**
 *  数据源
 */
@property (nonatomic, strong) NSArray * arrayDS;
@end

@implementation TestUIControlVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"UIControl";
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor lightGrayColor];
    [self createUI];
}
- (void)createUI{
    UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(20, 100, 150, 40)];
    datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    // 设置可供选择的最小时间：昨天
    NSTimeInterval time = 24 * 60 * 60; // 24H 的时间戳值
    datePicker.minimumDate = [[NSDate alloc] initWithTimeIntervalSinceNow:- time];
    // 设置可供选择的最大时间：明天
    datePicker.maximumDate = [[NSDate alloc] initWithTimeIntervalSinceNow:time];
    // 添加 Target-Action
    [datePicker addTarget:self
                   action:@selector(datePickerValueChanged:)
         forControlEvents:UIControlEventValueChanged];
    if (@available(iOS 13.4, *)) {
        datePicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    [self.view addSubview:datePicker];
    
    UITextView *textView = [[UITextView alloc]initWithFrame:CGRectMake(20, CGRectGetMaxY(datePicker.frame)+10, 100, 100)];
    if (@available(iOS 15.0, *)) {
        textView.textColor = [UIColor systemCyanColor];
    }
    [self.view addSubview:textView];
    self.textView = textView;
    UILabel *nameSelectLabel = [[UILabel alloc]initWithFrame:CGRectMake(20, CGRectGetMaxY(textView.frame)+10, 150, 40)];
    nameSelectLabel.backgroundColor = [UIColor whiteColor];
    nameSelectLabel.font = [UIFont systemFontOfSize:12];
    self.nameSelectLabel = nameSelectLabel;
    [self.view addSubview:self.nameSelectLabel];
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(180, CGRectGetMaxY(textView.frame)+10, 50, 40)];
    [button setTitle:@"选择" forState:UIControlStateNormal];
    [button setTitle:@"确认" forState:UIControlStateSelected];
    [button addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    self.button = button;
    [self initData];
    // 默认Picker状态
    [self resetPickerSelectRow];
}
- (void)buttonClick:(UIButton *)button{
    if(button.isSelected){
        [UIView animateWithDuration:0.1 animations:^{
            self.pickerView.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, PICKER_HEIGHT);
        }];
    }else{
        [UIView animateWithDuration:0.1 animations:^{
            self.pickerView.frame = CGRectMake(0, SCREEN_HEIGHT - PICKER_HEIGHT , SCREEN_WIDTH, PICKER_HEIGHT);
        }];
    }
    button.selected = !button.selected;
}
- (void)datePickerValueChanged:(id)sender{
    
}
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    if(self.button.selected){
        self.button.selected = !self.button.selected;
        self.nameSelectLabel.text = @"";
        [UIView animateWithDuration:0.1 animations:^{
            self.pickerView.frame = CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, PICKER_HEIGHT);
        }];
    }
    if(self.textView.isFirstResponder){
        [self.textView resignFirstResponder];
    }
}
-(void)initData
{
    _provinceIndex = _cityIndex = _districtIndex = 0;
}

#pragma mark - Load DataSource

// 读取本地Plist加载数据源
-(NSArray *)arrayDS
{
    if(!_arrayDS){
        NSString * path = [[NSBundle mainBundle] pathForResource:@"Province" ofType:@"plist"];
        _arrayDS = [[NSArray alloc] initWithContentsOfFile:path];
    }
    return _arrayDS;
}

// 懒加载方式
-(UIPickerView *)pickerView
{
    if(!_pickerView){
        _pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT, SCREEN_WIDTH, PICKER_HEIGHT)];
        _pickerView.dataSource = self;
        _pickerView.delegate = self;
        [self.view addSubview:_pickerView];
    }
    return _pickerView;
}

-(void)resetPickerSelectRow
{
    [self.pickerView selectRow:_provinceIndex inComponent:0 animated:YES];
    [self.pickerView selectRow:_cityIndex inComponent:1 animated:YES];
    [self.pickerView selectRow:_districtIndex inComponent:2 animated:YES];
}

#pragma mark - PickerView Delegate

// 列数
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 3;
}

// 每列有多少行
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if(component == 0){
        return self.arrayDS.count;
    }
    else if (component == 1){
        return [self.arrayDS[_provinceIndex][@"citys"] count];
    }
    else{
        return [self.arrayDS[_provinceIndex][@"citys"][_cityIndex][@"districts"] count];
    }
}

// 返回每一行的内容
-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if(component == 0){
        return self.arrayDS[row][@"province"];
    }
    else if (component == 1){
        return self.arrayDS[_provinceIndex][@"citys"][row][@"city"];
    }
    else{
        return self.arrayDS[_provinceIndex][@"citys"][_cityIndex][@"districts"][row];
    }
}

// 滑动或点击选择，确认pickerView选中结果
-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    
    if(component == 0){
        _provinceIndex = row;
        _cityIndex = 0;
        _districtIndex = 0;
        
        [self.pickerView reloadComponent:1];
        [self.pickerView reloadComponent:2];
    }
    else if (component == 1){
        _cityIndex = row;
        _districtIndex = 0;
        
        [self.pickerView reloadComponent:2];
    }
    else{
        _districtIndex = row;
    }
    NSString * address = [NSString stringWithFormat:@"%@-%@-%@", self.arrayDS[_provinceIndex][@"province"], self.arrayDS[_provinceIndex][@"citys"][_cityIndex][@"city"], self.arrayDS[_provinceIndex][@"citys"][_cityIndex][@"districts"][_districtIndex]];
    
    self.nameSelectLabel.text = address;

    // 重置当前选中项
    [self resetPickerSelectRow];
}

#pragma mark - Touch

//// 确认最后选中的结果
//-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
//{
//    // 省市区地址
//#warning 看明白Province.plist的结构，理解下边内容就不再是问题
//    NSString * address = [NSString stringWithFormat:@"%@-%@-%@", self.arrayDS[_provinceIndex][@"province"], self.arrayDS[_provinceIndex][@"citys"][_cityIndex][@"city"], self.arrayDS[_provinceIndex][@"citys"][_cityIndex][@"districts"][_districtIndex]];
//    
//    self.nameSelectLabel.text = address;
//}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
