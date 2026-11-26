//
//  FTSwizzlerConflictTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/5/16.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <XCTest/XCTest.h>
#import "FTNetworkMock.h"
#import "Firebase.h"
#import "FTSwizzler.h"
#import "objc/runtime.h"
#import <stdatomic.h>
#import "FTURLSessionInstrumentation.h"
#import "GuanceSDK.h"
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
@interface FTTestDelegateForwarder : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic) NSUInteger forwardingCalls;
@end

@implementation FTTestDelegateForwarder
- (id)forwardingTargetForSelector:(SEL)selector {
    // Bound the test double so a cycle regression fails without hanging the test runner.
    return ++_forwardingCalls <= 2 ? _target : nil;
}
@end

@interface FTDynamicSessionDelegate : NSObject<NSURLSessionDataDelegate>
@property (nonatomic) NSUInteger dataCallbacks;
@end

@implementation FTDynamicSessionDelegate
@end

static atomic_uint FTDelegateClassRetains;
static __weak FTDynamicSessionDelegate *FTDelegateBeingResolved;
static __unsafe_unretained Class FTDelegateClassAfterResolution;

static Class FTAllocateTestDelegateClass(__unsafe_unretained Class superclass) {
    NSString *name = [@"FTDynamicSessionDelegate_" stringByAppendingString:NSUUID.UUID.UUIDString];
    return objc_allocateClassPair(superclass, name.UTF8String, 0);
}

static const void *FTCountDelegateClassRetain(__unsafe_unretained id receiver, __unused SEL selector) {
    // Class objects do not have an instance retain count. Record ARC calls without altering runtime metadata.
    atomic_fetch_add_explicit(&FTDelegateClassRetains, 1, memory_order_relaxed);
    return (__bridge const void *)receiver;
}

static void FTCountDelegateDataCallback(FTDynamicSessionDelegate *delegate, __unused SEL selector,
                                       __unused NSURLSession *session, __unused NSURLSessionDataTask *task,
                                       __unused NSData *data) {
    delegate.dataCallbacks++;
}

static BOOL FTResolveDelegateDataCallback(__unsafe_unretained Class cls, __unused SEL command, SEL selector) {
    if (selector != @selector(URLSession:dataTask:didReceiveData:)) {
        return NO;
    }

    FTDynamicSessionDelegate *delegate = FTDelegateBeingResolved;
    object_setClass(delegate, FTDelegateClassAfterResolution);
    return class_addMethod(cls, selector, (IMP)FTCountDelegateDataCallback, "v@:@@@");
}

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
- (void)testDelegateClassResolutionFollowsForwardingAndRejectsCycles {
    SEL callback = @selector(URLSession:dataTask:didReceiveData:);
    FTTestDelegateForwarder *first = [FTTestDelegateForwarder new];
    FTTestDelegateForwarder *second = [FTTestDelegateForwarder new];
    DelegateSwizzlerClass *delegate = [DelegateSwizzlerClass new];
    first.target = second;
    second.target = delegate;

    __unsafe_unretained Class targetClass = Nil;
    [FTSwizzler getRealDelegateClassFromSelector:callback proxy:first result:&targetClass];
    XCTAssertEqual(targetClass, object_getClass(delegate));
    XCTAssertEqual(first.forwardingCalls, 1u);
    XCTAssertEqual(second.forwardingCalls, 1u);

    second.target = nil;
    [FTSwizzler getRealDelegateClassFromSelector:callback proxy:first result:&targetClass];
    XCTAssertEqual(targetClass, object_getClass(second));

    first.forwardingCalls = 0;
    second.forwardingCalls = 0;
    second.target = first;
    [FTSwizzler getRealDelegateClassFromSelector:callback proxy:first result:&targetClass];
    XCTAssertEqual(targetClass, Nil);
    XCTAssertEqual(first.forwardingCalls, 1u);
    XCTAssertEqual(second.forwardingCalls, 1u);

    first.forwardingCalls = 0;
    first.target = first;
    targetClass = object_getClass(first);
    [FTSwizzler getRealDelegateClassFromSelector:callback proxy:first result:&targetClass];
    XCTAssertEqual(targetClass, Nil);
    XCTAssertEqual(first.forwardingCalls, 1u);
}

- (void)testSessionFactoryHooksDynamicDelegateWithoutRetainingItsClass {
    __unsafe_unretained Class originalClass = FTDynamicSessionDelegate.class;
    __unsafe_unretained Class generatedClass = FTAllocateTestDelegateClass(originalClass);
    XCTAssertTrue(generatedClass != Nil);
    if (!generatedClass) return;

    SEL callback = @selector(URLSession:dataTask:didReceiveData:);
    XCTAssertTrue(class_addMethod(generatedClass, callback, (IMP)FTCountDelegateDataCallback, "v@:@@@"));
    XCTAssertTrue(class_addMethod(object_getClass(generatedClass), sel_registerName("retain"),
                                  (IMP)FTCountDelegateClassRetain, "@@:"));
    objc_registerClassPair(generatedClass);

    FTDynamicSessionDelegate *delegate = [FTDynamicSessionDelegate new];
    object_setClass(delegate, generatedClass);
    atomic_store_explicit(&FTDelegateClassRetains, 0, memory_order_relaxed);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration
                                                        delegate:delegate
                                                   delegateQueue:nil];
    unsigned int factoryRetains = atomic_load_explicit(&FTDelegateClassRetains, memory_order_relaxed);

    XCTAssertEqual(factoryRetains, 0u);
    XCTAssertTrue(session.delegate == delegate);
    XCTAssertTrue(object_getClass(delegate) == generatedClass);
    XCTAssertTrue(class_getSuperclass(generatedClass) == originalClass);
    XCTAssertTrue(class_getMethodImplementation(generatedClass, callback) != (IMP)FTCountDelegateDataCallback);

    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"https://offline.invalid"]];
    [(id<NSURLSessionDataDelegate>)session.delegate URLSession:session dataTask:task didReceiveData:[NSData data]];
    XCTAssertEqual(delegate.dataCallbacks, 1u);
    [session invalidateAndCancel];
}

- (void)testSessionFactoryHooksClassSelectedDuringDynamicMethodResolution {
    __unsafe_unretained Class originalClass = FTAllocateTestDelegateClass(FTDynamicSessionDelegate.class);
    XCTAssertTrue(originalClass != Nil);
    if (!originalClass) return;

    XCTAssertTrue(class_addMethod(object_getClass(originalClass), @selector(resolveInstanceMethod:),
                                  (IMP)FTResolveDelegateDataCallback, "B@::"));
    objc_registerClassPair(originalClass);

    __unsafe_unretained Class resolvedClass = FTAllocateTestDelegateClass(originalClass);
    XCTAssertTrue(resolvedClass != Nil);
    if (!resolvedClass) return;

    SEL callback = @selector(URLSession:dataTask:didReceiveData:);
    XCTAssertTrue(class_addMethod(resolvedClass, callback, (IMP)FTCountDelegateDataCallback, "v@:@@@"));
    objc_registerClassPair(resolvedClass);

    FTDynamicSessionDelegate *delegate = [originalClass new];
    FTDelegateBeingResolved = delegate;
    FTDelegateClassAfterResolution = resolvedClass;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration
                                                        delegate:delegate
                                                   delegateQueue:nil];
    FTDelegateBeingResolved = nil;
    FTDelegateClassAfterResolution = Nil;

    XCTAssertTrue(session.delegate == delegate);
    XCTAssertTrue(object_getClass(delegate) == resolvedClass);
    XCTAssertTrue(class_getMethodImplementation(originalClass, callback) == (IMP)FTCountDelegateDataCallback);
    XCTAssertTrue(class_getMethodImplementation(resolvedClass, callback) != (IMP)FTCountDelegateDataCallback);

    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"https://offline.invalid"]];
    [(id<NSURLSessionDataDelegate>)session.delegate URLSession:session dataTask:task didReceiveData:[NSData data]];
    XCTAssertEqual(delegate.dataCallbacks, 1u);
    [session invalidateAndCancel];
}

- (void)setSDK{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSString *url = [processInfo environment][@"ACCESS_SERVER_URL"];
    NSString *appid = [processInfo environment][@"APP_ID"];
    FTMobileConfig *config = [[FTMobileConfig alloc]initWithDatakitUrl:url];
    config.enableSDKDebugLog = YES;
    FTRumConfig *rumConfig = [[FTRumConfig alloc]initWithAppid:appid];
    rumConfig.enableTraceUserResource = YES;
    rumConfig.enableTraceUserView = YES;
    rumConfig.enableTraceUserAction = YES;
    [FTMobileAgent startWithConfigOptions:config];
    [[FTMobileAgent sharedInstance] startRumWithConfigOptions:rumConfig];
    [[FTTrackerEventDBTool sharedManager] deleteAllDatas];
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
