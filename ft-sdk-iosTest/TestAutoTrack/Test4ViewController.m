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
#import "AppDelegate.h"
#import <FTMobileAgent/ZYDataBase/ZYTrackerEventDBTool.h>
#import <FTMobileAgent/Interceptor/FTRecordModel.h>
@interface Test4ViewController ()<UITableViewDelegate,UITableViewDataSource>

@property(nonatomic,strong) UITableView *tableView;
@property (nonatomic, copy) NSString *lastUserData;
@property (nonatomic, copy) NSString *lastSessionId;
@end

@implementation Test4ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"testChangeUser";
     if ([self isAutoTrackVC]) {
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];
     }
    self.view.backgroundColor = [UIColor purpleColor];
    [self setIsShowLiftBack];
    [self createUI];
}
- (void)createUI{
    [self.view addSubview:self.tableView];
     UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:@"logout" forState:UIControlStateNormal];
        
        button.backgroundColor = [UIColor redColor];
        button.frame = CGRectMake(50, 100, 90, 30);
        
        [button addTarget:self action:@selector(otherButtonClick) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];


        UIButton *button1 = [UIButton buttonWithType:UIButtonTypeCustom];
        [button1 setTitle:@"newlogin" forState:UIControlStateNormal];
        button1.backgroundColor = [UIColor redColor];
        button1.frame = CGRectMake(50, 150, 90, 30);
        [button1 addTarget:self action:@selector(testClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button1];
        UILabel *lab = [[UILabel alloc]initWithFrame:CGRectMake(200, 150, 90, 40)];
           lab.backgroundColor = [UIColor yellowColor];
        lab.text = @"labTap";
        [self.view addSubview:lab];
        UITapGestureRecognizer *tap2 = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(labtapClick)];
        lab.userInteractionEnabled = YES;
        [lab addGestureRecognizer:tap2];
    
}
- (void)setIsShowLiftBack
{
    NSInteger VCCount = self.navigationController.viewControllers.count;
    //下面判断的意义是 当VC所在的导航控制器中的VC个数大于1 或者 是present出来的VC时，才展示返回按钮，其他情况不展示
    if (( VCCount > 1 || self.navigationController.presentingViewController != nil)) {
        [self addNavigationItemWithImageNames:@[@"icon_back"] isLeft:YES target:self action:@selector(backBtnClicked) tags:nil];
        
    } else {
        self.navigationItem.hidesBackButton = YES;
        UIBarButtonItem * NULLBar=[[UIBarButtonItem alloc]initWithCustomView:[UIView new]];
        self.navigationItem.leftBarButtonItem = NULLBar;
    }
}
- (void)addNavigationItemWithImageNames:(NSArray *)imageNames isLeft:(BOOL)isLeft target:(id)target action:(SEL)action tags:(NSArray *)tags
{
    NSMutableArray * items = [[NSMutableArray alloc] init];
    //调整按钮位置
    //    UIBarButtonItem* spaceItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    //    //将宽度设为负值
    //    spaceItem.width= -5;
    //    [items addObject:spaceItem];
    NSInteger i = 0;
    for (NSString * imageName in imageNames) {
        UIButton * btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
        [btn setImage:[UIImage imageNamed:imageName] forState:UIControlStateSelected];
        btn.frame = CGRectMake(0, 0, 30, 30);
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        
        if (isLeft) {
            [btn setContentEdgeInsets:UIEdgeInsetsMake(0, -10, 0, 10)];
        }else{
            [btn setContentEdgeInsets:UIEdgeInsetsMake(0, 10, 0, -10)];
        }
        
        btn.tag = [tags[i++] integerValue];
        UIBarButtonItem * item = [[UIBarButtonItem alloc] initWithCustomView:btn];
        [items addObject:item];
        
    }
    if (isLeft) {
        self.navigationItem.leftBarButtonItems = items;
    } else {
        self.navigationItem.rightBarButtonItems = items;
    }
}
- (void)backBtnClicked
{
    if ([self isAutoTrackVC] && [self isAutoTrackUI:UIButton.class]) {
        [[UITestManger sharedManger] addAutoTrackClickCount];
    }
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }else{
        [self.navigationController popViewControllerAnimated:YES];
    }
    
}
- (void)labtapClick{
    NSLog(@"tap点击");
     if ([self isAutoTrackVC] && [self isAutoTrackUI:UILabel.class]) {
    [[UITestManger sharedManger] addAutoTrackClickCount];
     }
    NSArray *array = [[ZYTrackerEventDBTool sharedManger] getFirstTenData];
    if (array.count>0) {
     FTRecordModel *model =  [array lastObject];
    self.lastUserData =model.userdata;
    }
    self.lastSessionId = [FTRecordModel new].sessionid;
}

-(void)testClick:(UIButton *)sender{

    NSLog(@"testClick");
    if ([self isAutoTrackVC] && [self isAutoTrackUI:UIButton.class]) {

    [[UITestManger sharedManger] addAutoTrackClickCount];
    }
    [[FTMobileAgent sharedInstance] bindUserWithName:@"newUser" Id:@"newUserId" exts:nil];

}

-(void)otherButtonClick{

    NSLog(@"点我了ya ");
    if ([self isAutoTrackVC] && [self isAutoTrackUI:UIButton.class]) {
    [[UITestManger sharedManger] addAutoTrackClickCount];
    }
    [[FTMobileAgent sharedInstance] logout];
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
    if ([self isAutoTrackVC] && [self isAutoTrackUI:UITableView.class]) {

    [[UITestManger sharedManger] addAutoTrackClickCount];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 2) {
        NSString *sessionId = [FTRecordModel new].sessionid;
        NSArray *array = [[ZYTrackerEventDBTool sharedManger] getFirstTenData];
        NSString *userData;
        if (array.count>0) {
        FTRecordModel *model =  [array lastObject];
            userData = model.userdata;
        }
        if (![sessionId isEqualToString:self.lastSessionId]) {
            UILabel *result = [[UILabel alloc]initWithFrame:CGRectMake(100, 550, 200, 300)];
            result.backgroundColor = [UIColor yellowColor];
            result.numberOfLines = 0;
            result.text =[NSString stringWithFormat: @"newuserdata : %@\n lastUserData : %@ \n newSessionId : %@\n lastsessionId : %@",userData,self.lastUserData,sessionId,self.lastSessionId];
            [self.view addSubview:result];
            UILabel *result2 = [[UILabel alloc]initWithFrame:CGRectMake(350, 550, 50, 50)];
            result2.backgroundColor = [UIColor yellowColor];
            result2.numberOfLines = 0;
            result2.text = @"changeUserSuccess";
            [self.view addSubview:result2];
        }
       
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void)dealloc{
     if ([self isAutoTrackVC]) {
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];
     }
}
- (BOOL)isAutoTrackUI:(Class )view{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
   
    if (appDelegate.config.whiteViewClass.count>0) {
        [appDelegate.config.whiteViewClass containsObject:view];
    }
    if(appDelegate.config.blackViewClass.count>0)
        return ! [appDelegate.config.blackViewClass containsObject:view];;
    return YES;
}
- (BOOL)isAutoTrackVC{
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (!appDelegate.config.enableAutoTrack) {
        return NO;
    }
     if (appDelegate.config.whiteVCList.count>0) {
         [appDelegate.config.whiteVCList containsObject:@"Test4ViewController"];
     }
     if(appDelegate.config.blackVCList.count>0)
         return ! [appDelegate.config.blackVCList containsObject:@"Test4ViewController"];;
     return YES;
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
