//
//  TestCustomTrackVC.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/6/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestCustomTrackVC.h"
#import <FTMobileAgent/FTMobileAgent.h>

@interface TestCustomTrackVC ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic, strong) UITableView *mtableView;
@property (nonatomic, strong) NSArray *dataSource;

@end

@implementation TestCustomTrackVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.dataSource = @[@[@"Test_TrackBackground",@"Test_TrackImmediate",@"Test_TrackImmediateList"],
                        @[@"Test_Logging"]];
    [self createUI];
    // Do any additional setup after loading the view.
}
-(void)createUI{
    
    _mtableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-200)];
    _mtableView.dataSource = self;
    _mtableView.delegate = self;
    _mtableView.vtpAddIndexPath = YES;
    [self.view addSubview:_mtableView];
    [_mtableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
}
- (void)testTrackBackground{
    [[FTMobileAgent sharedInstance] trackBackground:@"track ,Test" tags:nil field:@{@"ev，ent":@"te s，t"}];
}
- (void)testTrackImmediate{
    [[FTMobileAgent sharedInstance] trackImmediate:@"testImmediateList" field:@{@"test":@"testImmediate"} callBack:^(NSInteger statusCode, id  _Nonnull responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
}
- (void)testTrackImmediateList{
    //bean1 用户自己传时间  bean2 自动赋值
    FTTrackBean *bean1 = [FTTrackBean new];
    bean1.measurement = @"testImmediateList";
    bean1.field =@{@"test":@"testImmediateList"};
    NSDate *datenow = [NSDate date];
    long time= (long)([datenow timeIntervalSince1970]*1000);
    bean1.timeMillis =time;
    FTTrackBean *bean2 = [FTTrackBean new];
    bean2.measurement = @"testImmediateList2";
    bean2.field =@{@"test":@"testImmediateList2"};
    
    [[FTMobileAgent sharedInstance] trackImmediateList:@[bean1,bean2] callBack:^(NSInteger statusCode, id  _Nonnull responseObject) {
        NSLog(@"responseObject = %@",responseObject);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
    
}
-(void)testLoggingBackground{
    [[FTMobileAgent sharedInstance] logging:@"TestLoggingBackground" status:FTStatusInfo];
}

-(void)showResult:(NSString *)title{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *commit = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:commit];
    [self presentViewController:alert animated:YES completion:nil];
}
#pragma mark ========== UITableViewDataSource ==========
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    NSArray *array =self.dataSource[section];
    return array.count;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return self.dataSource.count;
}
-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    NSString *title;
    switch (section) {
        case 0:
            title = @"track";
            break;
        case 1:
            title = @"logging";
            break;
        default:
            break;
    }
    return title;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.textLabel.text = self.dataSource[indexPath.section][indexPath.row];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSUInteger row = [indexPath row];
    switch (indexPath.section) {
        case 0:{
            switch (row) {
                case 0:
                    [self testTrackBackground];
                    break;
                case 1:
                    [self testTrackImmediate];
                    break;
                case 2:
                    [self testTrackImmediateList];
                    break;
                default:
                    break;
            }
        }
            break;
        case 1:{
            switch (row) {
                case 0:
                    [self testLoggingBackground];
                    break;
                default:
                    break;
            }
        }
            break;
        default:
            break;
            
    }
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
