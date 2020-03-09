//
//  TestSubFlowTrack2.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/3/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestSubFlowTrack2.h"
#import "SubFlowTrack1.h"
#import "SubFlowTrack2.h"
#import "SubFlowTrack3.h"
@interface TestSubFlowTrack2 ()
@property (nonatomic, strong) SubFlowTrack1 *track1;
@property (nonatomic, strong) SubFlowTrack2 *track2;
@property (nonatomic, strong) SubFlowTrack3 *track3;
@end

@implementation TestSubFlowTrack2

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TestSubFlowTrack2";
    [self createUI];
}
- (void)createUI{
    //添加子控制器 移除子控制器  子控制器会进入生命周期  可以正常抓取到-viewDidAppear
    self.track1 = [SubFlowTrack1 new];
    self.track2 = [SubFlowTrack2 new];
    self.track3 = [SubFlowTrack3 new];
    UISegmentedControl * segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"FlowTrack1",@"FlowTrack2",@"FlowTrack3"]];
    segmentedControl.tintColor = [UIColor blueColor];
    segmentedControl.frame = CGRectMake(0, 86, [UIScreen mainScreen].bounds.size.width, 44);
    [segmentedControl addTarget:self action:@selector(segCChanged:) forControlEvents:UIControlEventValueChanged];
    segmentedControl.selectedSegmentIndex = 0;
    [self displayContentController:self.track1];
    [self.view addSubview:segmentedControl];
    
}
-(void)segCChanged:(UISegmentedControl *)seg

{

    NSInteger i = seg.selectedSegmentIndex;
    
    [self.childViewControllers enumerateObjectsUsingBlock:^(__kindof UIViewController * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self hideContentController:obj];
    }];
    if (i==0) {
        [self displayContentController:self.track1];
    }else if (i==1){
         [self displayContentController:self.track2];
    }else{
         [self displayContentController:self.track3];
    }
    
   
}
- (void)displayContentController: (UIViewController*) content {
   // 步骤a
   [self addChildViewController:content];
   // 步骤b
   content.view.frame = CGRectMake(0, 130, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-130);
   // 步骤c
   [self.view addSubview:content.view];
   // 步骤d
   [content didMoveToParentViewController:self];
}
- (void) hideContentController:(UIViewController*) content {
    // 步骤a
   [content willMoveToParentViewController:nil];
   // 步骤b
   [content.view removeFromSuperview];
   // 步骤c
   [content removeFromParentViewController];
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
