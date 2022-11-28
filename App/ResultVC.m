//
//  SecondViewController.m
//  RuntimDemo
//
//  Created by 胡蕾蕾 on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import "ResultVC.h"
#import "AppDelegate.h"
#import "FTMobileAgent.h"
#import "FTThread.h"
#import "FTTrackerEventDBTool.h"
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
    if([[[NSProcessInfo processInfo] environment][@"isUITests"] boolValue]){
        [self upload];
    }
}
//强制上传
-(void)upload{
//    [[FTTrackDataManger sharedInstance] setValue:@NO forKey:@"isUploading"];
//    FTThread *thread = [[FTTrackDataManger sharedInstance] valueForKey:@"ftThread"];
//    [[FTTrackDataManger sharedInstance] performSelector:@selector(privateUpload) onThread:thread withObject:nil waitUntilDone:NO];
}
-(void)checkResult{
    //数据库写入操作是异步的 等待数据写入
    dispatch_after(5, dispatch_get_main_queue(), ^{
        NSArray *datas = [[FTTrackerEventDBTool sharedManger] getFirstRecords:50 withType:FT_DATA_TYPE_RUM];
       
        if(datas.count>0){
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
