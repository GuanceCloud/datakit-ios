//
//  TodayViewController.m
//  TodayExtensionTest
//
//  Created by hulilei on 2020/11/17.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "GuanceWidgetExtension.h"
#import <GuanceWidgetExtension/FTMobileConfig.h>
#import <GuanceWidgetExtension/FTExternalDataManager.h>
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
