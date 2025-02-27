//
//  TestPageVC.m
//  App
//
//  Created by hulilei on 2025/2/20.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import "TestPageVC.h"
#import "ContentViewController.h"

@interface TestPageVC ()<UIPageViewControllerDataSource,UIPageViewControllerDelegate>
@property (nonatomic, strong) UIPageViewController *pageViewController;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation TestPageVC
- (UIPageViewController *)pageViewController {
    if (!_pageViewController) {
        // 设置水平滚动
        UIPageViewController *pageVc = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                                      navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                                    options:nil];
        pageVc.dataSource = self;
        pageVc.delegate = self;
        _pageViewController = pageVc;
    }
    return _pageViewController;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self addPageViewController];
       
       // 设置初始化显示视图控制器
    [self.pageViewController setViewControllers:@[[self pages][self.currentIndex]]
                                         direction:UIPageViewControllerNavigationDirectionForward
                                          animated:YES
                                        completion:nil];
}
- (void)addPageViewController {
    [self addChildViewController:self.pageViewController];
    self.pageViewController.view.frame = self.view.bounds;
    [self.view addSubview:self.pageViewController.view];
    [self.pageViewController didMoveToParentViewController:self];
}

// 页面数据（示例使用不同颜色）
- (NSArray<ContentViewController *> *)pages {
    static NSArray<ContentViewController *> *pages = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ContentViewController *vc1 = [[ContentViewController alloc] initWithPageIndex:0 bgColor:[UIColor systemRedColor]];
        ContentViewController *vc2 = [[ContentViewController alloc] initWithPageIndex:1 bgColor:[UIColor systemGreenColor]];
        ContentViewController *vc3 = [[ContentViewController alloc] initWithPageIndex:2 bgColor:[UIColor systemBlueColor]];
        pages = @[vc1,vc2,vc3];
    });
    return pages;
}

// 获取前一个页面
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[ContentViewController class]]) {
        ContentViewController *currentVC = (ContentViewController *)viewController;
        if (currentVC.pageIndex > 0) {
            return self.pages[currentVC.pageIndex - 1];
        }
    }
    return nil;
}

// 获取后一个页面
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    if ([viewController isKindOfClass:[ContentViewController class]]) {
        ContentViewController *currentVC = (ContentViewController *)viewController;
        if (currentVC.pageIndex < self.pages.count - 1) {
            return self.pages[currentVC.pageIndex + 1];
        }
    }
    return nil;
}

// 可选：显示页面指示器
- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    return self.pages.count;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    if (pageViewController.viewControllers.count > 0) {
        ContentViewController *firstVC = pageViewController.viewControllers.firstObject;
        if ([firstVC isKindOfClass:[ContentViewController class]]) {
            return firstVC.pageIndex;
        }
    }
    return 0;
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
