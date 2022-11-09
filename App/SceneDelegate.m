#import "SceneDelegate.h"
#import "DemoViewController.h"
#import "UITestVC.h"
#import <FTMobileAgent/FTMobileAgent.h>
@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions  API_AVAILABLE(ios(13.0)){
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.windowScene = (UIWindowScene*)scene;
    UITabBarController *tab = [[UITabBarController alloc]init];
    DemoViewController *rootVC = [[DemoViewController alloc] init];
    rootVC.title = @"home";
   
    UINavigationController *rootNav = [[UINavigationController alloc] initWithRootViewController:rootVC];
    UITestVC *second =  [UITestVC new];
    second.title = @"uitest";
    UINavigationController *rootNav2 = [[UINavigationController alloc] initWithRootViewController:second];

    tab.viewControllers = @[rootNav,rootNav2];
    tab.tabBar.items.firstObject.title = @"home";
    tab.tabBar.items.firstObject.isAccessibilityElement = YES;
    tab.tabBar.items.lastObject.title = @"UITEST";
    tab.tabBar.items.lastObject.isAccessibilityElement = YES;
    self.window.rootViewController = tab;
    
    [self.window makeKeyAndVisible];
}


- (void)sceneDidDisconnect:(UIScene *)scene  API_AVAILABLE(ios(13.0)){
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene  API_AVAILABLE(ios(13.0)){
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    BOOL isUnitTests = [[processInfo environment][@"isUnitTests"] boolValue];
    BOOL isUITests = [[processInfo environment][@"isUITests"] boolValue];
    if (!isUnitTests && !isUITests) {
        [[FTMobileAgent sharedInstance] trackEventFromExtensionWithGroupIdentifier:@"group.com.ft.widget.demo" completion:nil];
    }
}


- (void)sceneWillResignActive:(UIScene *)scene  API_AVAILABLE(ios(13.0)){
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}


- (void)sceneWillEnterForeground:(UIScene *)scene  API_AVAILABLE(ios(13.0)){
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene  API_AVAILABLE(ios(13.0)){
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}


@end
