//
//  SubFlowTrack3.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/3/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import "SubFlowTrack3.h"

@interface SubFlowTrack3 ()

@end

@implementation SubFlowTrack3

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blueColor];
    NSLog(@"parentViewController = %@",self.parentViewController);
    // Do any additional setup after loading the view.
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
}
-(void)viewWillAppear:(BOOL)animated{
    
}
-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    
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
