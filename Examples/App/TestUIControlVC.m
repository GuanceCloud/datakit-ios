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
    NSInteger _provinceIndex;   // Province selection record
    NSInteger _cityIndex;       // City selection record
    NSInteger _districtIndex;   // District selection record
}
@property (strong, nonatomic) UILabel *nameSelectLabel;
@property (nonatomic, strong) UIPickerView * pickerView;
@property (nonatomic, strong) UIButton * button;
@property (nonatomic, strong) UITextView *textView;
/**
 *  Data source
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
    // Set minimum selectable time: yesterday
    NSTimeInterval time = 24 * 60 * 60; // 24H timestamp value
    datePicker.minimumDate = [[NSDate alloc] initWithTimeIntervalSinceNow:- time];
    // Set maximum selectable time: tomorrow
    datePicker.maximumDate = [[NSDate alloc] initWithTimeIntervalSinceNow:time];
    // Add Target-Action
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
    [button setTitle:@"Select" forState:UIControlStateNormal];
    [button setTitle:@"Confirm" forState:UIControlStateSelected];
    [button addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    self.button = button;
    [self initData];
    // Default Picker state
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

// Read local Plist to load data source
-(NSArray *)arrayDS
{
    if(!_arrayDS){
        NSString * path = [[NSBundle mainBundle] pathForResource:@"Province" ofType:@"plist"];
        _arrayDS = [[NSArray alloc] initWithContentsOfFile:path];
    }
    return _arrayDS;
}

// Lazy loading method
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

// Number of columns
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 3;
}

// Number of rows in each column
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

// Return content of each row
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

// Slide or click to select, confirm pickerView selection result
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

    // Reset current selection
    [self resetPickerSelectRow];
}

#pragma mark - Touch

//// Confirm final selection result
//-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
//{
//    // Province-city-district address
//#warning Understand the structure of Province.plist, then understanding the content below is no longer a problem
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
