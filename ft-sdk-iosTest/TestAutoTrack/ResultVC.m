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
#import <FTMobileAgent/FTDataBase/FTTrackerEventDBTool.h>
#import "UITestManger.h"
#import <FTMobileAgent/FTUploadTool.h>

@interface ResultVC ()
@property (nonatomic ,strong) FTMobileConfig *config;

@property (nonatomic, strong) UILabel *lable;
@end

@implementation ResultVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Result";
    self.view.backgroundColor = [UIColor whiteColor];
    if ([self isAutoTrackVC]) {
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];
    }
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.config = appDelegate.config;
    [self createUI];
    [self setIsShowLiftBack];
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
- (void)createUI{
   
   
    
    UILabel *lable = [[UILabel alloc]initWithFrame:CGRectMake(10, 230, 350, 250)];
    lable.backgroundColor = [UIColor whiteColor];
    lable.textColor = [UIColor blackColor];
    lable.numberOfLines = 0;
    lable.text = [NSString stringWithFormat:@"数据库原有数据 %ld 条\n 数据库增加：\nlunch:%ld\nopen、close：%ld \nclick:%ld \n数据库现有数据： %ld 条 \n",[UITestManger sharedManger].lastCount,[UITestManger sharedManger].trackCount,[UITestManger sharedManger].autoTrackViewScreenCount,[UITestManger sharedManger].autoTrackClickCount,[[FTTrackerEventDBTool sharedManger] getDatasCount]];
    
    self.lable = lable;
    [self.view addSubview:lable];
    dispatch_queue_t queue = dispatch_queue_create("net.test.testQueue", DISPATCH_QUEUE_SERIAL);
      
       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(90 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           dispatch_async(queue, ^{
             NSInteger count = [self getUploadInfo];
             [self judjeSuccessWithCount:count];
           dispatch_async(dispatch_get_main_queue(), ^{
               // 追加在主线程中执行的任务
               self.lable.text = [NSString stringWithFormat:@"数据库原有数据 %ld 条\n 数据库增加：\nlunch:%ld\nopen、close：%ld \nclick:%ld \n数据库现有数据： %ld 条 \n上传：%ld条",[UITestManger sharedManger].lastCount,[UITestManger sharedManger].trackCount,[UITestManger sharedManger].autoTrackViewScreenCount,[UITestManger sharedManger].autoTrackClickCount,[[FTTrackerEventDBTool sharedManger] getDatasCount],(long)count];
           });
           });
       });
}

-(void)judjeSuccessWithCount:(NSInteger)count{
    NSInteger realCount= [UITestManger sharedManger].lastCount;
    if (self.config.enableAutoTrack) {
       
            realCount+=[UITestManger sharedManger].autoTrackClickCount;
        
            realCount+=[UITestManger sharedManger].autoTrackViewScreenCount;
        
            realCount +=[UITestManger sharedManger].trackCount;
    }
    
    if(realCount-[[FTTrackerEventDBTool sharedManger] getDatasCount] == count){
        dispatch_async(dispatch_get_main_queue(), ^{
            UILabel *lab = [[UILabel alloc]initWithFrame:CGRectMake(270, 100, 50, 50)];
                   lab.text = @"SUCCESS";
                   lab.backgroundColor = [UIColor redColor];
                   [self.view addSubview:lab];
        });
    }
}
-(NSString *)login{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *account =[processInfo environment][@"FTTestAccount"];
    NSString *password = [processInfo environment][@"FTTestPassword"];
    if (account.length>0 && password.length>0) {
        NSLog(@"account:%@,password:%@",account,password);
    }else{
        return @"";
    }
    NSURL *url = [NSURL URLWithString:@"http://testing.api-ft2x.cloudcare.cn:10531/api/v1/auth-token/login"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];    //拷贝request
             mutableRequest.HTTPMethod = @"POST";
              //添加header
        [mutableRequest addValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];

                 //设置请求参数
             [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
    NSDictionary *param = @{
        @"username": account,
        @"password": password,
        @"workspaceUUID": [NSString stringWithFormat:@"wksp_%@",[[NSUUID UUID] UUIDString]],
    };
    NSData* data = [NSJSONSerialization dataWithJSONObject:param options:NSJSONWritingPrettyPrinted error:nil];
    NSString *bodyData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
    [mutableRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
    

    request = [mutableRequest copy];
    __block NSString *token = @"";
             
                        //设置请求session
                        NSURLSession *session = [NSURLSession sharedSession];
                        dispatch_group_t group = dispatch_group_create();
                        dispatch_group_enter(group);

                        //设置网络请求的返回接收器
                        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (error) {
                                    
                                }else{
                                    NSError *errors;
                                    NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
                                    
                                    if (!errors){
                                        NSDictionary *content = [responseObject valueForKey:@"content"];
                                        token = [content valueForKey:@"token"];
                                    }
                                }
                                 dispatch_group_leave(group);
                            });
                               
                        }];
                    //开始请求
                        [dataTask resume];
                    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    return token;
}
-(NSInteger)getUploadInfo{
         NSString *token = [self login];
          NSURL *url = [NSURL URLWithString:@"http://testing.api-ft2x.cloudcare.cn:10531/api/v1/influx/query_data"];
          NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
              //设置请求地址
          //添加header
          NSMutableURLRequest *mutableRequest = [request mutableCopy];    //拷贝request
          mutableRequest.HTTPMethod = @"POST";
           //添加header
          [mutableRequest addValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];

              //设置请求参数
          [mutableRequest setValue:token forHTTPHeaderField:@"X-FT-Auth-Token"];
          [mutableRequest setValue:@"zh-CN" forHTTPHeaderField:@"Accept-Language"];
           NSDictionary *param = [self getParams];
          NSData* data = [NSJSONSerialization dataWithJSONObject:param options:NSJSONWritingPrettyPrinted error:nil];
          NSString *bodyData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
              
          [mutableRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
          request = [mutableRequest copy];        //拷贝回去
          __block NSInteger count = 0;
          
                     //设置请求session
                     NSURLSession *session = [NSURLSession sharedSession];
                     dispatch_group_t group = dispatch_group_create();
                     dispatch_group_enter(group);

                     //设置网络请求的返回接收器
                     NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                         dispatch_async(dispatch_get_main_queue(), ^{
                             if (error) {
                                 
                             }else{
                                 NSError *errors;
                                 NSMutableDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&errors];
                                 
                                 if (!errors){
                                   NSDictionary *content= [responseObject valueForKey:@"content"];
                                     NSArray *data = [content valueForKey:@"data"];
                                     NSArray *series = [[data firstObject] valueForKey:@"series"];
                                     if (![series isKindOfClass:[NSNull class]] && ![series isEqual:[NSNull null]]) {
                                         NSArray *values = [[series firstObject] valueForKey:@"values"];

                                          count = values.count;
                                     }
                                 }
                             }
                              dispatch_group_leave(group);
                         });
                            
                     }];
                 //开始请求
                     [dataTask resume];
                 dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

             return count;

}
-(NSDictionary *)getParams{
    NSDictionary *param = @{@"qtype":@"http",
                            @"query":@{@"filter":@{@"tags":@[@{@"name":@"application_identifier",
                                                             @"condition":@"",
                                                             @"operation":@"=",
                                                             @"value":@"HLL.ft-sdk-iosTest",
                            }],
                                                   @"time":[self getTime],
                            },
                                       @"measurements":@[@"mobile_tracker"],
                                       @"tz":@"Asia/Shanghai",
                                       @"orderBy":@[@{@"name":@"time",
                                                    @"method":@"desc"}],
                                       @"offset":@0,
                                       @"limit":@1000,
                                       @"fields":@[@{@"name":@"event"}],
                                       
                            },
    };
    
    return param;
}
-(NSArray *)getTime{
    NSDate *datenow = [NSDate date];
    long  time= (long)([datenow timeIntervalSince1970]*1000);
    return @[[NSNumber numberWithLong:time-(1000 * 60 * 3)],[NSNumber numberWithLong:time]];
}
-(void)dealloc{
    if ([self isAutoTrackVC]) {
        [[UITestManger sharedManger] addAutoTrackViewScreenCount];
    }
}
- (BOOL)isAutoTrackVC{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (!appDelegate.config.enableAutoTrack) {
        return NO;
    }
     if (appDelegate.config.whiteVCList.count>0) {
         [appDelegate.config.whiteVCList containsObject:@"ResultVC"];
     }
     if(appDelegate.config.blackVCList.count>0)
         return ! [appDelegate.config.blackVCList containsObject:@"ResultVC"];;
     return YES;
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
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
