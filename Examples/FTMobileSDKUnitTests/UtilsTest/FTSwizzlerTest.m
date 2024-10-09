//
//  FTSwizzlerTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTSwizzler.h"
#import "FTLog+Private.h"
#import <objc/runtime.h>
static void *IMP_resolved_method_implementation(void){
    return nil;
}
@protocol FTBaseDelegate <NSObject>
- (NSString *)baseSring:(NSString *)str;
@end
@interface BaseSwizzlerClass : NSObject<FTBaseDelegate>
- (void)noArgument;
- (void)oneArgument:(NSString *)first;
- (void)twoArgument:(NSString *)first second:(NSString *)second;
- (void)threeArgument:(NSString *)first second:(NSString *)second third:(NSString *)third;
- (void)boolArgument:(BOOL)animation;
- (void)exceedArgument:(NSString *)first second:(NSString *)second third:(NSString *)third fourth:(NSString *)fourth;

@end
@implementation BaseSwizzlerClass
- (void)noArgument{
    
}
- (void)boolArgument:(BOOL)animation{
    
}
- (void)oneArgument:(NSString *)first{
    
}
- (void)twoArgument:(NSString *)first second:(NSString *)second{
    
}
- (void)threeArgument:(NSString *)first second:(NSString *)second third:(NSString *)third{
    
}
- (void)exceedArgument:(NSString *)first second:(NSString *)second third:(NSString *)third fourth:(NSString *)fourth{
    
}
-(NSString *)baseSring:(NSString *)str{
    return [NSString stringWithFormat:@"aa%@",str];
}
@end
@interface SubSwizzlerClass : BaseSwizzlerClass

@end
@implementation SubSwizzlerClass
-(void)noArgument{
    [super noArgument];
}
@end
@interface FTSwizzlerTest : XCTestCase
@property (nonatomic, weak) id <FTBaseDelegate> delegate;
@property (nonatomic, strong) SubSwizzlerClass *sub;
@property (nonatomic, strong) SubSwizzlerClass *nullSub;

@end

@implementation FTSwizzlerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testSwizzleNoArg{
    __block BOOL swizzled = NO;
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(noArgument), FTSWReturnType(void), FTSWArguments(), FTSWReplacement({
        swizzled = YES;
        FTSWCallOriginal();
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleNoArg");
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base noArgument];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleOneArg{
    __block BOOL swizzled = NO;
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(oneArgument:), FTSWReturnType(void), FTSWArguments(NSString *first), FTSWReplacement({
        swizzled = YES;
        FTSWCallOriginal(first);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleOneArg");
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base oneArgument:@"first"];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleTwoArg{
    __block BOOL swizzled = NO;
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(twoArgument:second:), FTSWReturnType(void), FTSWArguments(NSString *first,NSString *second), FTSWReplacement({
        swizzled = YES;
        FTSWCallOriginal(first,second);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleTwoArg");
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base twoArgument:@"first" second:@"second"];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleThreeArg{
    __block BOOL swizzled = NO;
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(threeArgument:second:third:), FTSWReturnType(void), FTSWArguments(NSString *first,NSString *second,NSString *third), FTSWReplacement({
        swizzled = YES;
        FTSWCallOriginal(first,second,third);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleThreeArg");
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base threeArgument:@"first" second:@"second" third:@"third"];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleBoolArg{
    __block BOOL swizzled = NO;
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(boolArgument:), FTSWReturnType(void), FTSWArguments(BOOL animation), FTSWReplacement({
        swizzled = YES;
        FTSWCallOriginal(animation);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleBoolArg");
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base boolArgument:YES];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleWrongOriSelector{
    SEL wrongOriSelector = @selector(selector_ori_no_existed);

    XCTAssertThrows([FTSwizzler swizzleInstanceMethod:wrongOriSelector inClass:BaseSwizzlerClass.class newImpFactory:^id(FTSwizzlerInfo *swizzleInfo) {
        return nil;
    } mode:FTSwizzlerModeOncePerClassAndSuperclasses key:"testSwizzleWrongOriSelector"]);
}
- (void)testSwizzleSuperMethod{
    __block NSInteger times = 0;
    FTSwizzlerInstanceMethod(SubSwizzlerClass.class, @selector(oneArgument:), FTSWReturnType(void), FTSWArguments(NSString *first), FTSWReplacement({
        times ++;
        FTSWCallOriginal(first);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleSuperMethod");

    SubSwizzlerClass *base = [SubSwizzlerClass new];
    [base oneArgument:@"first"];
    XCTAssertTrue(times == 1);
}
- (void)testSwizzleSuperMethodSubClassUse{
    __block NSInteger times = 0;
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(noArgument), FTSWReturnType(void), FTSWArguments(), FTSWReplacement({
        times ++;
        FTSWCallOriginal();
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleSuperMethodSubClassUse");
    
    SubSwizzlerClass *base = [SubSwizzlerClass new];
    [base noArgument];
    XCTAssertTrue(times == 1);
}
- (void)testSwizzleDelegate{
    self.sub = [SubSwizzlerClass new];
    SEL selector = @selector(baseSring:);
    self.delegate = self.sub;
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:self.delegate];
    __block NSInteger times = 0;
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        FTSwizzlerInstanceMethod(class, selector, FTSWReturnType(NSString*), FTSWArguments(NSString *str), FTSWReplacement({
            times += 1;
            return FTSWCallOriginal(str);
        }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleDelegate");
    }
    [self.sub baseSring:@"first"];
    XCTAssertTrue(times == 1);
}
- (void)testSwizzleNullDelegate{
    SEL selector = @selector(baseSring:);
    self.delegate = self.nullSub;
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:self.delegate];
    __block NSInteger times = 0;
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        FTSwizzlerInstanceMethod(class, selector, FTSWReturnType(NSString*), FTSWArguments(NSString *str), FTSWReplacement({
            times += 1;
            return FTSWCallOriginal(str);
        }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleNullDelegate");
    }
    [self.sub baseSring:@"first"];
    XCTAssertTrue(times == 0);
}
- (void)testSwizzleAsync{
    __block NSInteger times = 0;
    SubSwizzlerClass *base = [SubSwizzlerClass new];
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(noArgument), FTSWReturnType(void), FTSWArguments(), FTSWReplacement({
        @synchronized (self) {
            times ++;
        }
        FTSWCallOriginal();
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleAsync");
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(noArgument), FTSWReturnType(void), FTSWArguments(), FTSWReplacement({
                    times ++;
                FTSWCallOriginal();
            }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzleAsync");
            dispatch_group_leave(group);
        });
        [base noArgument];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    XCTAssertTrue(times == 1000);
}
-(void)testCallingMethodAsync{
    __block NSInteger times = 0;
    SubSwizzlerClass *base = [SubSwizzlerClass new];
    XCTestExpectation *exception = [[XCTestExpectation alloc]init];
    dispatch_group_t group = dispatch_group_create();
    FTSwizzlerInstanceMethod(BaseSwizzlerClass.class, @selector(noArgument), FTSWReturnType(void), FTSWArguments(), FTSWReplacement({
        @synchronized (self) {
            times ++;
        }
        FTSWCallOriginal();
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testCallingMethodAsync");
    for (int i = 0; i<1000; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [base noArgument];
            NSLog(@"%d %ld",i,times);
            dispatch_group_leave(group);
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [exception fulfill];
    });
    [self waitForExpectations:@[exception]];
    XCTAssertTrue(times == 1000);
}

- (void)testSwizzlerWrongMethodType{
    SubSwizzlerClass *base = [SubSwizzlerClass new];
    SEL addMethod = NSSelectorFromString(@"playing:");
    IMP replace = (IMP)IMP_resolved_method_implementation;

    class_addMethod(SubSwizzlerClass.class, addMethod, replace, "^v@:");
    __block NSString *testStr = @"";
    FTSwizzlerInstanceMethod(SubSwizzlerClass.class, addMethod, FTSWReturnType(void), FTSWArguments(NSString *str), FTSWReplacement({
        NSLog(@"[testSwizzlerWrongMethodType] %@",str);
        testStr = str;
        FTSWCallOriginal(str);
    }), FTSwizzlerModeOncePerClassAndSuperclasses, "testSwizzlerWrongMethodType");
    
    XCTAssertNoThrow([base performSelector:addMethod withObject:@"test"]);
    XCTAssertTrue([testStr isEqualToString:@"test"]);
}
@end
