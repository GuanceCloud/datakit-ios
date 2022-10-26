
#import "AppDelegate.h"
#import <Foundation/Foundation.h>
#import <FTMobileAgent/FTMobileAgent.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithMetricsUrl:@"YOUR Datakit URL"];
    [FTMobileAgent startWithConfigOptions:config];
    
    return YES;
}

@end
