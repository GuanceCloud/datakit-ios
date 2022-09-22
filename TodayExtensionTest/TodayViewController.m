//
//  TodayViewController.m
//  TodayExtensionTest
//
//  Created by 胡蕾蕾 on 2020/11/17.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "FTMobileExtension.h"
#import <FTMobileExtension/FTMobileConfig.h>
#import <FTMobileExtension/FTExternalDataManager.h>
@interface TodayViewController () <NCWidgetProviding>

@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *appid = [processInfo environment][@"APP_ID"];
    [FTExtensionManager enableLog:YES];
    [FTExtensionManager startWithApplicationGroupIdentifier:@"group.com.ft.extension.demo"];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]init];
    rumConfig.appid = appid;
    rumConfig.enableTrackAppCrash = YES;
    rumConfig.enableTraceUserResource = YES;
    FTTraceConfig *traceConfig = [[FTTraceConfig alloc]init];
    traceConfig.enableLinkRumData = YES;
    traceConfig.enableAutoTrace = YES;
    [[FTExtensionManager sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTExtensionManager sharedInstance] startTraceWithConfigOptions:traceConfig];
    [[FTExternalDataManager sharedManager] startViewWithName:@"TodayViewController"];
}
- (IBAction)crashClick:(id)sender {
     NSString *value = nil;
     NSDictionary *dict = @{@"11":value};
}
- (IBAction)networkClick:(id)sender {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://testing-ft2x-api.cloudcare.cn/api/v1/account/permissions"]];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        
    }];
    NSURL *url = [NSURL URLWithString:@"http://testing-ft2x-api.cloudcare.cn/api/v1/account/permissions"];
    NSMutableURLRequest *request2 = [NSMutableURLRequest requestWithURL:url];
    
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request2 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
    }];
    
    [task resume];
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

@end
