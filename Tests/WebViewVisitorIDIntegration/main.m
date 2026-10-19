#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
@import GuanceSDK;
@interface NativeClock:NSObject
@property(nonatomic,strong) NSDate *date;
@end
@implementation NativeClock
-(NSDate *)now{return self.date;}
@end
@interface AppDelegate:UIResponder<UIApplicationDelegate,WKScriptMessageHandler>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) NSMutableArray *results;
@property(nonatomic,strong) NSArray *cases;
@property(nonatomic,assign) NSUInteger index;
@property(nonatomic,strong) id savedClock;
@end
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@end
@implementation AppDelegate
-(id)manager{return [NSClassFromString(@"FTVisitorIDManager") performSelector:NSSelectorFromString(@"sharedInstance")];}
-(NSString *)current{return [[self manager] performSelector:NSSelectorFromString(@"currentVisitorID")];}
-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options{
 self.results=[NSMutableArray array];NSMutableArray *cases=[NSMutableArray array];
 for(NSString *bundle in @[@"full",@"slim"])for(NSString *scenario in @[@"native",@"unavailable",@"invalid",@"throwing",@"denied",@"nativeDisabled",@"webDisabled",@"noBridge"])[cases addObject:@{@"bundle":bundle,@"scenario":scenario}];self.cases=cases;
 return YES;
}
-(void)save{
 NSString *directory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
 NSDictionary *report=@{@"results":self.results,@"completed":@(self.index>=self.cases.count),@"platform":UIDevice.currentDevice.systemVersion};
 [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil]writeToFile:[directory stringByAppendingPathComponent:@"results.json"] atomically:YES];
}
-(void)next{
 if(self.savedClock){[[self manager]setValue:self.savedClock forKey:@"clock"];self.savedClock=nil;}
 [FTSDKAgent shutDown];
 if(self.index>=self.cases.count){[self save];return;}
 NSDictionary *test=self.cases[self.index];NSString *scenario=test[@"scenario"];
 NSString *initial=@"p0123456789abcdef0123456789abcdef";
 [[NSUserDefaults standardUserDefaults]setObject:@{@"version":@1,@"id":initial,@"createdAt":@([NSDate date].timeIntervalSince1970)} forKey:@"com.guance.sdk.visitor-id.record"];
 FTSDKConfig *base=[[FTSDKConfig alloc]initWithDatakitUrl:@"http://127.0.0.1:18763"];base.autoSync=NO;base.allowWebViewHost=[scenario isEqualToString:@"denied"]?@[@"other.example"]:@[@"127.0.0.1"];
 [FTSDKAgent startWithConfigOptions:base];FTRumConfig *rum=[[FTRumConfig alloc]initWithAppid:@"webvisitor-integration"];
 rum.enableTraceWebView=![scenario isEqualToString:@"noBridge"];
 if(![scenario isEqualToString:@"nativeDisabled"]){FTVisitorIDConfig *visitor=[FTVisitorIDConfig new];visitor.header=@"x-native-visitor";visitor.ttlHours=1.0/60;[visitor addMatchWithURLPrefix:@"http://127.0.0.1:18763/native-only"];rum.visitorIDConfig=visitor;}
 [[FTSDKAgent sharedInstance]startRumWithConfigOptions:rum];
 WKWebViewConfiguration *configuration=[WKWebViewConfiguration new];configuration.websiteDataStore=[WKWebsiteDataStore nonPersistentDataStore];[configuration.userContentController addScriptMessageHandler:self name:@"integration"];
 self.webView=[[WKWebView alloc]initWithFrame:self.window.rootViewController.view.bounds configuration:configuration];self.webView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 for(UIView *view in self.window.rootViewController.view.subviews)[view removeFromSuperview];[self.window.rootViewController.view addSubview:self.webView];[self.webView becomeFirstResponder];
 if(![scenario isEqualToString:@"noBridge"])[[FTWKWebViewHandler sharedInstance]enableWebView:self.webView allowWebViewHost:base.allowWebViewHost];
 NSString *url=[NSString stringWithFormat:@"http://127.0.0.1:18763/?bundle=%@&scenario=%@",test[@"bundle"],scenario];[self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
 NSUInteger index=self.index;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,40*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(self.index==index){[self.results addObject:@{@"bundle":test[@"bundle"],@"scenario":scenario,@"failures":@[@{@"message":@"native case timeout"}]}];self.index++;[self save];[self next];}});
}
-(void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message{
 NSDictionary *body=message.body;
 if(body[@"result"]){[self.results addObject:body[@"result"]];self.index++;[self save];dispatch_async(dispatch_get_main_queue(),^{[self next];});return;}
 NSString *command=body[@"command"];if([command isEqualToString:@"reset"])[FTSDKAgent resetVisitorID];
 if([command isEqualToString:@"expire"]){self.savedClock=[[self manager]valueForKey:@"clock"];NativeClock *clock=[NativeClock new];clock.date=[NSDate dateWithTimeIntervalSinceNow:61];[[self manager]setValue:clock forKey:@"clock"];}
 if([command isEqualToString:@"disable"])[[self manager]performSelector:NSSelectorFromString(@"shutDown")];
 id value=[self current]?:NSNull.null;NSData *data=[NSJSONSerialization dataWithJSONObject:@[body[@"id"],value] options:0 error:nil];NSString *args=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 [self.webView evaluateJavaScript:[NSString stringWithFormat:@"window.__resolveCommand.apply(null,%@)",args] completionHandler:nil];
}
@end
@implementation SceneDelegate
-(void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options{
 AppDelegate *app=(AppDelegate *)UIApplication.sharedApplication.delegate;
 app.window=[[UIWindow alloc]initWithWindowScene:(UIWindowScene *)scene];app.window.rootViewController=[UIViewController new];[app.window makeKeyAndVisible];[app next];
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
