//
//  NetworkTraceVC.m
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "NetworkTraceVC.h"
#import "TableViewCellItem.h"
#import <FTMobileSDK/FTMobileSDK.h>

@interface NetworkTraceVC ()<UITableViewDelegate,UITableViewDataSource,NSURLSessionDataDelegate>
@property (nonatomic, strong) UITableView *mTableView;
@property (nonatomic, strong) NSArray<NSArray*> *datas;

@end

@implementation NetworkTraceVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"network data collection";
    self.view.backgroundColor = [UIColor whiteColor];
    [self createUI];
}
- (void)createUI{
    // enableTraceUserResource = YES;
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    __weak typeof(self) weakSelf = self;
    TableViewCellItem *item1 = [[TableViewCellItem alloc]initWithTitle:@"RUM, Trace enable Resource auto collection" handler:^{
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        }];
        [task resume];
        [session finishTasksAndInvalidate];
    }];
    // To avoid data duplication, please disable enableTraceUserResource
    TableViewCellItem *item2 = [[TableViewCellItem alloc]initWithTitle:@"Register `FTURLSessionDelegate`" handler:^{
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:[[FTURLSessionDelegate alloc]init] delegateQueue:nil];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        }];
        [task resume];
        [session finishTasksAndInvalidate];
    }];
    TableViewCellItem *item3 = [[TableViewCellItem alloc]initWithTitle:@"Intercept Request, custom Trace" handler:^{
        FTURLSessionDelegate *delegateProxy = [[FTURLSessionDelegate alloc]init];
        delegateProxy.requestInterceptor = ^NSURLRequest * _Nonnull(NSURLRequest * _Nonnull request) {
            NSMutableURLRequest *newRequest = [request mutableCopy];
            [newRequest setValue:@"interceptor" forHTTPHeaderField:@"test"];
            return newRequest;
        };
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegateProxy delegateQueue:nil];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        }];
       
        [task resume];
        [session finishTasksAndInvalidate];
    }];
    TableViewCellItem *item4 = [[TableViewCellItem alloc]initWithTitle:@"Add RUM Resource additional resources" handler:^{
        FTURLSessionDelegate *delegateProxy = [[FTURLSessionDelegate alloc]init];
        delegateProxy.provider = ^NSDictionary * _Nullable(NSURLRequest * _Nullable request, NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable error) {
            NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            if(body&&body.length>0){
                [dict setValue:body forKey:@"df_data"];
            }
            if(error){
                [dict setValue:error.description forKey:@"df_error"];
            }
            return dict;
        };
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegateProxy delegateQueue:nil];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
        }];
       
        [task resume];
        [session finishTasksAndInvalidate];
    }];
    
    TableViewCellItem *item5 = [[TableViewCellItem alloc]initWithTitle:@"Manual operation: use open api operation" handler:^{
        NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
        NSURL *url = [NSURL URLWithString:urlStr];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLRequest *addTraceRequest = [[FTURLSessionInterceptor shared] interceptRequest:request];
        NSURLSession *session=[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:weakSelf delegateQueue:[NSOperationQueue mainQueue]];
        NSURLSessionTask *task = [session dataTaskWithRequest:addTraceRequest];
        [[FTURLSessionInterceptor shared] interceptTask:task];
        [task resume];
        [session finishTasksAndInvalidate];
    }];
    
    self.datas = @[@[item1],@[item2,item3,item4],@[item5]];
    self.mTableView.dataSource = self;
    self.mTableView.delegate = self;
    [self.mTableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"UITableViewCell"];
    [self.view addSubview:self.mTableView];
}
-(UITableView *)mTableView{
    if(!_mTableView){
        _mTableView = [[UITableView alloc]initWithFrame:self.view.frame style:UITableViewStylePlain];
    }
    return _mTableView;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 3;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.datas[section].count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if(section == 0){
        return @"Use Autotrace";
    }else if(section == 1){
        return @"URLSession Auto Instrumentation";
    }else{
        return @"Use Manual";
    }
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    TableViewCellItem *item = self.datas[indexPath.section][indexPath.row];
    if(item.subTitle.length>0){
        return 75;
    }
    return 45;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell =  [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"UITableViewCell"];
    TableViewCellItem *item = self.datas[indexPath.section][indexPath.row];
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = item.subTitle;
    cell.detailTextLabel.numberOfLines = 0;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    TableViewCellItem *item = self.datas[indexPath.section][indexPath.row];
    if (item.handler) {
        item.handler();
    }
}
#pragma mark --------- NSURLSessionDataDelegate ----------

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)){
    [[FTURLSessionInterceptor shared] taskMetricsCollected:task metrics:metrics];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    [[FTURLSessionInterceptor shared] taskReceivedData:dataTask data:data];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [[FTURLSessionInterceptor shared] taskCompleted:task error:error extraProvider:nil];
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
