//
//  HomeViewController.m
//  FTSDKiOSDemo
//
//  Created by 胡蕾蕾 on 2019/12/13.
//  Copyright © 2019 hll. All rights reserved.
//

#import "HomeViewController.h"
#import "SecondViewController.h"
#import <FTMobileAgent/FTMobileAgent.h>

@interface HomeViewController ()<UITableViewDelegate,UITableViewDataSource>
@property(nonatomic,strong) UITableView *tableView;

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 100, 100)];
    button.backgroundColor = [UIColor redColor];
    [button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
          [self.view addSubview:button];
    [self.view addSubview:self.tableView];
    // Do any additional setup after loading the view.
}
- (void)buttonClick{
   [[FTMobileAgent sharedInstance] track:@"home.operation" tags:@{@"pushVC":@"SecondViewController"} values:@{@"event":@"BtnClick"}];
   [self.navigationController pushViewController:[SecondViewController new] animated:YES];
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
    cell.textLabel.text = @"来点我呀";
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [[FTMobileAgent sharedInstance] track:@"home.operation" tags:@{@"index":[NSNumber numberWithLong:indexPath.row]} values:@{@"event":@"cellClick"}];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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
