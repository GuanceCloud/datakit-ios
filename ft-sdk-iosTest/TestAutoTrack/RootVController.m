//
//  RootViewController.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/2/26.
//  Copyright © 2020 hll. All rights reserved.
//

#import "RootVController.h"
#import "UITestManger.h"
@interface RootVController ()

@end

@implementation RootVController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
        // Do any additional setup after loading the view.
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];

}
-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [[UITestManger sharedManger] addAutoTrackViewScreenCount];

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
