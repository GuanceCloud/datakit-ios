//
//  SubFlowTrack1.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/3/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import "SubFlowTrack1.h"

@interface SubFlowTrack1 ()

@end

@implementation SubFlowTrack1

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor redColor];
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
