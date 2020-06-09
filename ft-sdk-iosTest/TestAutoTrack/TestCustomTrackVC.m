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
                        @[@"Test_LoggingBackground",@"Test_LoggingImmediate",@"Test_LoggingImmediateList"],
                        @[@"Test_ObjectBackground",@"Test_ObjectImmediate",@"Test_ObjectImmediateList"],
                        @[@"Test_KeyeventBackground",@"Test_KeyeventImmediate",@"Test_KeyeventImmediateList"]];
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
    FTLoggingBean *logging = [FTLoggingBean new];
    logging.measurement = @"Test";
    logging.content = @"TestLoggingBackground";
    [[FTMobileAgent sharedInstance] loggingBackground:logging];
}
- (void)testLoggingImmediate{
    FTLoggingBean *logging = [FTLoggingBean new];
    logging.measurement = @"Test";
    logging.content = @"TestLogging";
    [[FTMobileAgent sharedInstance] loggingImmediate:logging callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
}
- (void)testLoggingImmediateList{
    FTLoggingBean *logging = [FTLoggingBean new];
    logging.measurement = @"Test";
    logging.content = @"TestLoggingList1";
    FTLoggingBean *logging2 = [FTLoggingBean new];
    logging2.measurement = @"Test";
    logging2.content = @"TestLoggingList2";
    [[FTMobileAgent sharedInstance] loggingImmediateList:@[logging,logging2] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
}
- (void)testObjectBackground{
    [[FTMobileAgent sharedInstance] objectBackground:@"TestObjectBackground" deviceUUID:nil tags:nil classStr:@"ObjectBackground"];
}
- (void)testObjectImmediate{
    [[FTMobileAgent sharedInstance] objectImmediate:@"TestObjectImmediate" deviceUUID:nil tags:nil classStr:@"ObjectImmediate" callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
}
- (void)testObjectImmediateList{
    FTObjectBean *object1 = [FTObjectBean new];
    object1.name =@"TestObjectImmediateList";
    object1.classStr = @"ObjectImmediateList1";
    FTObjectBean *object2 = [FTObjectBean new];
    object2.name =@"TestObjectImmediateList";
    object2.classStr = @"ObjectImmediateList2";
    [[FTMobileAgent sharedInstance] objectImmediateList:@[object1,object2] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
}

- (void)testKeyeventBackground{
    FTKeyeventBean *key = [FTKeyeventBean new];
    key.title = @"testKeyeventBackground";
    key.content = @"测试KeyeventBackground";
    [[FTMobileAgent sharedInstance] keyeventBackground:key];
}
- (void)testKeyeventImmediate{
    FTKeyeventBean *key = [FTKeyeventBean new];
    key.title = @"testKeyeventImmediate";
    key.content = @"测试KeyeventImmediate";
    [[FTMobileAgent sharedInstance] keyeventImmediate:key callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
               dispatch_async(dispatch_get_main_queue(), ^{
                   [self showResult:statusCode==200?@"success":@"fail"];
               });
    }];
}
- (void)testKeyeventImmediateList{
    FTKeyeventBean *key = [FTKeyeventBean new];
    key.title = @"testKeyeventImmediateList1";
    key.content = @"测试KeyeventImmediateList数据1";

    FTKeyeventBean *key2 = [FTKeyeventBean new];
    key2.title = @"testKeyeventImmediateList2";
    key2.content = @"测试KeyeventImmediateList数据2";
    [[FTMobileAgent sharedInstance] keyeventImmediateList:@[key,key2] callBack:^(NSInteger statusCode, id  _Nullable responseObject) {
        NSLog(@"statusCode = %ld",(long)statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showResult:statusCode==200?@"success":@"fail"];
        });
    }];
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
        case 2:
            title = @"object";
            break;
        case 3:
            title = @"keyevent";
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
                case 1:
                    [self testLoggingImmediate];
                    break;
                case 2:
                    [self testLoggingImmediateList];
                    break;
                default:
                    break;
            }
        }
            break;
        case 2:{
            switch (row) {
                case 0:
                    [self testObjectBackground];
                    
                    break;
                case 1:
                    [self testObjectImmediate];
                    break;
                case 2:
                    [self testObjectImmediateList];
                    break;
                default:
                    break;
            }
        }
            break;
        case 3:{
            switch (row) {
                case 0:
                    [self testKeyeventBackground];
                    break;
                case 1:
                    [self testKeyeventImmediate];
                    break;
                case 2:
                    [self testKeyeventImmediateList];
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
