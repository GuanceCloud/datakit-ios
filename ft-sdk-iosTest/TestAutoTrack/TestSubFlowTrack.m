//
//  TestSubFlowTrack.m
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2020/3/9.
//  Copyright © 2020 hll. All rights reserved.
//

#import "TestSubFlowTrack.h"
#import "SubFlowTrack1.h"
#import "SubFlowTrack2.h"
#import "SubFlowTrack3.h"
#import "SubFlowTrackCell.h"
@interface TestSubFlowTrack ()<UICollectionViewDelegate,UICollectionViewDataSource>
@property (nonatomic, strong) NSArray *dataSource;
@property (nonatomic, strong) UICollectionView *collectionView;
@end

@implementation TestSubFlowTrack

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TestSubFlowTrack";
    [self createSubVC];
}
- (void)createSubVC{
    SubFlowTrack1 *track1 = [SubFlowTrack1 new];
    SubFlowTrack2 *track2 = [SubFlowTrack2 new];
    SubFlowTrack3 *track3 = [SubFlowTrack3 new];
    SubFlowTrack1 *track4 = [SubFlowTrack1 new];
    SubFlowTrack2 *track5 = [SubFlowTrack2 new];
    SubFlowTrack3 *track6 = [SubFlowTrack3 new];
    self.dataSource = @[track1,track2,track3,track4,track5,track6];
    [self.view addSubview:self.collectionView];
    [self.collectionView reloadData];
}
- (UIViewController *)getCurrentVC
{
    // 定义一个变量存放当前屏幕显示的viewcontroller
    UIViewController *result = nil;
    
    // 得到当前应用程序的关键窗口（正在活跃的窗口）
    UIWindow * window = [[UIApplication sharedApplication] keyWindow];
    
    // windowLevel是在 Z轴 方向上的窗口位置，默认值为UIWindowLevelNormal
    if (window.windowLevel != UIWindowLevelNormal)
    {
        // 获取应用程序所有的窗口
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(UIWindow * tmpWin in windows)
        {
            // 找到程序的默认窗口（正在显示的窗口）
            if (tmpWin.windowLevel == UIWindowLevelNormal)
            {
                // 将关键窗口赋值为默认窗口
                window = tmpWin;
                break;
            }
        }
    }
    // 获取窗口的当前显示视图
    UIView *frontView = [[window subviews] objectAtIndex:0];
    
    // 获取视图的下一个响应者，UIView视图调用这个方法的返回值为UIViewController或它的父视图
    id nextResponder = [frontView nextResponder];
    
    // 判断显示视图的下一个响应者是否为一个UIViewController的类对象
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        result = nextResponder;
    } else {
        result = window.rootViewController;
    }
    return result;
}
-(void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView{
    NSLog(@"scrollViewDidEndScrollingAnimation %@",scrollView);
}
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated{
    NSLog(@"scrollToItemAtIndexPath %@",indexPath);
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    NSLog(@"subviews = %@", scrollView.subviews);
    NSLog(@"%@",NSStringFromCGPoint(scrollView.contentOffset)) ;
    if ([[self getCurrentViewController] isKindOfClass:UINavigationController.class]) {
        UINavigationController *nav =(UINavigationController*)[self getCurrentViewController];
        NSLog(@"UINavigationController = %@",nav.visibleViewController);
        if([nav.visibleViewController childViewControllers].count>0){
        NSLog(@"UINavigationController = %@",[nav.visibleViewController childViewControllers]);
        }
    }
}

- (UIViewController *)getCurrentViewController{
    UIResponder *next = [self nextResponder];
    do {if ([next isKindOfClass:[UIViewController class]]) {
        return (UIViewController *)next;
    }
        next = [next nextResponder];
    } while (next !=nil);
    return nil;
}
- (UICollectionView *)collectionView{
    if (!_collectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
        //该方法也可以设置itemSize
        layout.itemSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-100);
        layout.sectionInset = UIEdgeInsetsMake(0, 0 ,0, 0);
        layout.minimumLineSpacing = 0;

        
        _collectionView = [[UICollectionView alloc]initWithFrame:CGRectMake(0, 100, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-100) collectionViewLayout:layout];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.pagingEnabled = YES;
        _collectionView.scrollEnabled = YES;
        _collectionView.backgroundColor = [UIColor whiteColor];
        [_collectionView registerClass:[SubFlowTrackCell class] forCellWithReuseIdentifier:@"SubFlowTrackCell"];
        
    }
    return _collectionView;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.dataSource.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    SubFlowTrackCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"SubFlowTrackCell" forIndexPath:indexPath];
    [self addChildViewController:self.dataSource[indexPath.row]];
    UIViewController *vc = self.dataSource[indexPath.row];
    [cell addSubview:vc.view];
    return cell;
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
