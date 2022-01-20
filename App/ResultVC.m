//
//  SecondViewController.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ResultVC.h"
#import "AppDelegate.h"
#import <FTMobileAgent/FTMobileAgent.h>
#import <FTTrackerEventDBTool.h>
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTRecordModel.h"
@interface ResultVC ()
@property (nonatomic ,strong) FTMobileConfig *config;

@property (nonatomic, strong) UILabel *lable;
@property (nonatomic, strong) UILabel *successView;
@end

@implementation ResultVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Result";
    self.view.backgroundColor = [UIColor whiteColor];
    [self checkResult];
}
-(void)checkResult{
    //数据库写入操作是异步的 等待数据写入
    __block NSInteger viewCount,actionCount,longTaskCount,resourceCount = 0;
    __block NSMutableArray *viewAry = [NSMutableArray new];
    dispatch_after(5, dispatch_get_main_queue(), ^{
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
        [datas enumerateObjectsUsingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
            NSDictionary *opdata = dict[@"opdata"];
            NSString *measurement = opdata[FT_MEASUREMENT];
            if ([measurement isEqualToString:FT_MEASUREMENT_RUM_ACTION]) {
                actionCount++;
            }else if([measurement isEqualToString:FT_MEASUREMENT_RUM_VIEW]){
                viewCount ++;
                [viewAry addObject:obj];
            }else if([measurement isEqualToString:FT_MEASUREMENT_RUM_LONG_TASK]){
                longTaskCount ++;
            }else if([measurement isEqualToString:FT_MEASUREMENT_RUM_RESOURCE]){
                resourceCount ++;
            }
        }];
        self.lable.text = [NSString stringWithFormat:@"viewCount: %@ \nactionCount:%@",@(viewCount),@(actionCount)];
        if(viewCount == actionCount+resourceCount+longTaskCount && actionCount == 10){
            self.successView.backgroundColor = [UIColor redColor];
            self.successView.hidden = NO;
        }
    });
    //action:launch_cold -> view:UITabBarController ->resource ->view:DemoViewController->action:click->view:DemoViewController->action:click->view:DemoViewController->action:click->view:UITestVC........
    
}
-(UILabel *)successView{
    if (!_successView) {
        _successView = [[UILabel alloc]initWithFrame:CGRectMake(20, 150, 100, 40)];
        _successView.text = @"SUCCESS";
        [self.view addSubview:_successView];
    }
    return _successView;
}
-(UILabel *)lable{
    if (!_lable) {
        _lable = [[UILabel alloc]initWithFrame:CGRectMake(10, 230, 350, 250)];
        _lable.backgroundColor = [UIColor whiteColor];
        _lable.textColor = [UIColor blackColor];
        _lable.numberOfLines = 0;
        [self.view addSubview:_lable];
    }
    return _lable;
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
