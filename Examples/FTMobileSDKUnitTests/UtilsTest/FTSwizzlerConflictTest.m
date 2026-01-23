//
//  FTSwizzlerConflictTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/5/16.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTNetworkMock.h"
#import "Firebase.h"
#import "FTSwizzler.h"
#import "objc/runtime.h"
#import "FTURLSessionInstrumentation.h"
#import "FTMobileSDK.h"
#import "FTTrackerEventDBTool.h"
#import "NSDate+FTUtil.h"
#import "OHHTTPStubs.h"
@interface DelegateSwizzlerClass : NSObject<UITableViewDelegate,NSURLSessionDelegate,NSURLSessionDataDelegate>
@property (nonatomic, strong) NSString *nameStr;

@property (nonatomic, strong) NSString *name;
@end
@implementation DelegateSwizzlerClass

-(NSString *)name{
    return NSStringFromClass(object_getClass(self)) ;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
}
@end
@interface FTSwizzlerConflictTest : XCTestCase

@end

@implementation FTSwizzlerConflictTest

- (void)setUp {
    [FTNetworkMock networkOHHTTPStubs];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [OHHTTPStubs removeAllStubs];
}
- (void)setSDK{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManger] deleteAllDatas];
}
- (void)testTableViewDelegate_KVO{
    [self setSDK];
    for (int i = 0; i<1000; i++) {
        @autoreleasepool {
            UITableView *tableView = [[UITableView alloc]init];
            DelegateSwizzlerClass *delegateClass = [[DelegateSwizzlerClass alloc]init];
            [delegateClass addObserver:self forKeyPath:@"nameStr" options:NSKeyValueObservingOptionNew context:nil];
            tableView.delegate = delegateClass;
            XCTAssertTrue([delegateClass.name isEqualToString:@"NSKVONotifying_DelegateSwizzlerClass"]);
        }
    }
    [FTMobileAgent shutDown];
}
- (void)testTableViewDelegate{
    [self setSDK];
    
    for (int i = 0; i<1000; i++) {
        @autoreleasepool {
            UITableView *tableView = [[UITableView alloc]init];
            DelegateSwizzlerClass *delegateClass = [[DelegateSwizzlerClass alloc]init];
            [delegateClass addObserver:self forKeyPath:@"nameStr" options:NSKeyValueObservingOptionNew context:nil];
            tableView.delegate = delegateClass;
            XCTAssertTrue([delegateClass.name isEqualToString:@"NSKVONotifying_DelegateSwizzlerClass"]);
        }
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                DelegateSwizzlerClass *resourceDelegate = [[DelegateSwizzlerClass alloc]init];
                NSString *urlStr = [NSString stringWithFormat:@"http://testing-ft2x-api.cloudcare.cn/api/v1/account/permissions%d",i];
                NSURL *url = [NSURL URLWithString:urlStr];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:resourceDelegate delegateQueue:nil];
                NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
                }];
                [task resume];
                [session finishTasksAndInvalidate];
            });
    }
    [FTMobileAgent shutDown];
}
- (void)testURLSession_shareSession_firebase{
    [self setSDK];
    [FIRApp configureWithOptions:[self mockFIRAppOption]];
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSString *urlStr = [NSString stringWithFormat:@"http://testing-ft2x-api.cloudcare.cn/api/v1/account/permissions%d",i];
            NSURL *url = [NSURL URLWithString:urlStr];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            NSURLSession *session = [NSURLSession sharedSession];
            NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
                dispatch_group_leave(group);
            }];
            [task resume];
            [session finishTasksAndInvalidate];
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    [FIRApp performSelector:@selector(resetApps)];
    [FTMobileAgent shutDown];
}
- (void)testURLSession_customSession_noDelegate_firebase{
    [self setSDK];
    [FIRApp configureWithOptions:[self mockFIRAppOption]];
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSString *urlStr = [NSString stringWithFormat:@"http://testing-ft2x-api.cloudcare.cn/api/v1/account/permissions%d",i];
            NSURL *url = [NSURL URLWithString:urlStr];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
                dispatch_group_leave(group);
            }];
            [task resume];
            [session finishTasksAndInvalidate];
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    [FIRApp performSelector:@selector(resetApps)];
    [FTMobileAgent shutDown];
}
- (void)testURLSession_customSession_delegate_firebase{
    [self setSDK];
    [FIRApp configureWithOptions:[self mockFIRAppOption]];
    NSMutableSet *set = [NSMutableSet new];
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    NSLock *lock = [[NSLock alloc]init];
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            DelegateSwizzlerClass *delegate = [[DelegateSwizzlerClass alloc]init];
            NSString *urlStr = [NSString stringWithFormat:@"http://testing-ft2x-api.cloudcare.cn/api/v1/account/permissions%d",i];
            NSURL *url = [NSURL URLWithString:urlStr];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
            XCTAssertTrue(![delegate.name isEqualToString:@"DelegateSwizzlerClass"]);
            XCTAssertTrue([delegate.name containsString:@"fir_"]);
            [lock lock];
            [set addObject:delegate.name];
            [lock unlock];
            NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
                dispatch_group_leave(group);
            }];
            [task resume];
            [session finishTasksAndInvalidate];
            
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    BOOL classDealloc = NO;
    for (NSString *name in set) {
        if(NSClassFromString(name) == nil){
            classDealloc = YES;
            break;
        }
    }
    XCTAssertTrue(classDealloc);
    [FIRApp performSelector:@selector(resetApps)];
    [FTMobileAgent shutDown];
}
- (FIROptions *)mockFIRAppOption{
    NSInteger projectNumber = arc4random();
    uint64_t fingerprint;
    arc4random_buf(&fingerprint, sizeof(fingerprint));
    NSString *fingerprintHex = [NSString stringWithFormat:@"%llx", fingerprint];
    NSString *appID = [NSString stringWithFormat:@"1:%ld:ios:%@", projectNumber, fingerprintHex];
    
    FIROptions *options = [[FIROptions alloc]initWithGoogleAppID:appID GCMSenderID:[NSString stringWithFormat:@"%ld",(long)projectNumber]];
    options.APIKey = @"A0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ01";
    options.projectID = @"fir-poc-abcde";
    return options;
}
@end
