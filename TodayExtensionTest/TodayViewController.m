//
//  TodayViewController.m
//  TodayExtensionTest
//
//  Created by 胡蕾蕾 on 2020/11/17.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import <FTMobileExtension/FTExtensionManager.h>
@interface TodayViewController () <NCWidgetProviding>

@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [FTExtensionManager enableLog:YES];
    [FTExtensionManager startWithApplicationGroupIdentifier:@"group.hlltest.widget"];
}
- (IBAction)crashClick:(id)sender {
     NSString *value = nil;
     NSDictionary *dict = @{@"11":value};
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

@end
