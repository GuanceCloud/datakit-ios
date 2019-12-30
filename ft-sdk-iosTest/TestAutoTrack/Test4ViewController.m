//
//  Test4ViewController.m
//  AopTestDemo
//
//  Created by ChenMan on 2018/4/26.
//  Copyright © 2018年 cimain. All rights reserved.
//

#import "Test4ViewController.h"
#import "UITestVC.h"
#import "UITestManger.h"
@interface Test4ViewController ()<UITableViewDelegate,UITableViewDataSource>

@property(nonatomic,strong) UITableView *tableView;

@end

@implementation Test4ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];

    self.view.backgroundColor = [UIColor purpleColor];
    [self.view addSubview:self.tableView];
//    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"button 1" forState:UIControlStateNormal];
    
    button.backgroundColor = [UIColor redColor];
    button.frame = CGRectMake(100, 100, 90, 30);
    
    [button addTarget:self action:@selector(otherButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];


    UIButton *button1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [button1 setTitle:@"button 2" forState:UIControlStateNormal];
    button1.backgroundColor = [UIColor redColor];
    button1.frame = CGRectMake(100, 150, 90, 30);
    [button1 addTarget:self action:@selector(testClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button1];
    UILabel *lab = [[UILabel alloc]initWithFrame:CGRectMake(200, 150, 90, 40)];
       lab.backgroundColor = [UIColor yellowColor];
    lab.text = @"lab";
    [self.view addSubview:lab];
    UITapGestureRecognizer *tap2 = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(labtapClick)];
    lab.userInteractionEnabled = YES;
    [lab addGestureRecognizer:tap2];
//
//    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(200, 200, 90, 40)];
//    view.backgroundColor = [UIColor yellowColor];
//    [self.view addSubview:view];
//    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapClick)];
//    [view addGestureRecognizer:tap];
    
}
- (void)labtapClick{
    NSLog(@"tap点击");
    [[UITestManger sharedManger] addAutoTrackClickCount];
}
//-(void)tapClick{
//
//    NSLog(@"tap点击");
//    [[UITestManger sharedManger] addAutoTrackClickCount];
//
//}
//
-(void)testClick:(NSDictionary *)sender{

    NSLog(@"testClick");
    [[UITestManger sharedManger] addAutoTrackClickCount];

}

-(void)otherButtonClick{

    NSLog(@"点我了ya ");
    [[UITestManger sharedManger] addAutoTrackClickCount];

}


-(UITableView *)tableView{
    
    if (!_tableView) {
        _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 250, self.view.bounds.size.width, 200) style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.tableFooterView=[[UIView alloc]init];//去掉多余行的分割线
    }
    return  _tableView;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return 3;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *indentifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:indentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:indentifier];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"tableView Cell %ld",(long)indexPath.row];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [[UITestManger sharedManger] addAutoTrackClickCount];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 1) {
        UITestVC *test = [[UITestVC alloc]init];
        [self.navigationController pushViewController:test animated:YES];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
