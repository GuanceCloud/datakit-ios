//
//  FTSwizzlerTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/20.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTSwizzler.h"

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
/**
 
 
 + (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(datafluxSwizzleBlock)block named:(NSString *)aName;
 + (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass named:(NSString *)aName;
 + (void)printSwizzles;
 + (BOOL)realDelegateClass:(Class)cls respondsToSelector:(SEL)sel;
 + (Class)realDelegateClassFromSelector:(SEL)selector proxy:(id)proxy;
 */
- (void)testSwizzleNoArg{
    __block BOOL swizzled = NO;
    [FTSwizzler swizzleSelector:@selector(noArgument) onClass:BaseSwizzlerClass.class withBlock:^{
        swizzled = YES;
    } named:@"testSwizzleNoArg"];
    
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base noArgument];
    XCTAssertTrue(swizzled);
    [FTSwizzler printSwizzles];
}
- (void)testSwizzleOneArg{
    __block BOOL swizzled = NO;
    [FTSwizzler swizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class withBlock:^{
        swizzled = YES;
    } named:@"testSwizzleOneArg"];
    
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base oneArgument:@"first"];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleTwoArg{
    __block BOOL swizzled = NO;
    [FTSwizzler swizzleSelector:@selector(twoArgument:second:) onClass:BaseSwizzlerClass.class withBlock:^{
        swizzled = YES;
    } named:@"testSwizzleTwoArg"];
    
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base twoArgument:@"first" second:@"second"];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleThreeArg{
    __block BOOL swizzled = NO;
    [FTSwizzler swizzleSelector:@selector(threeArgument:second:third:) onClass:BaseSwizzlerClass.class withBlock:^{
        swizzled = YES;
    } named:@"testSwizzleThreeArg"];
    
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base threeArgument:@"first" second:@"second" third:@"third"];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleBoolArg{
    __block BOOL swizzled = NO;
    [FTSwizzler swizzleSelector:@selector(boolArgument:) onClass:BaseSwizzlerClass.class withBlock:^{
        swizzled = YES;
    } named:@"testSwizzleBoolArg"];
    
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base boolArgument:YES];
    XCTAssertTrue(swizzled);
}
- (void)testSwizzleSuperMethod{
    __block NSInteger times = 0;
    [FTSwizzler swizzleSelector:@selector(oneArgument:) onClass:SubSwizzlerClass.class withBlock:^(NSString *first){
        times += 1;
    } named:@"testSwizzleSuperMethod"];
    
    SubSwizzlerClass *base = [SubSwizzlerClass new];
    [base oneArgument:@"first"];
    XCTAssertTrue(times == 1);
    
}
- (void)testSwizzleSuperMethodSubClassUse{
    __block NSInteger times = 0;
    [FTSwizzler swizzleSelector:@selector(noArgument) onClass:BaseSwizzlerClass.class withBlock:^(NSString *first){
        times += 1;
    } named:@"testSwizzleSuperMethodSubClassUse"];
    
    SubSwizzlerClass *base = [SubSwizzlerClass new];
    [base noArgument];
    XCTAssertTrue(times == 1);
    
}
- (void)testUnswizzle{
    __block NSInteger times = 0;
    [FTSwizzler swizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class withBlock:^(NSString *first){
        times += 1;
    } named:@"testUnswizzle1"];
    [FTSwizzler swizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class withBlock:^(NSString *first){
        times += 1;
    } named:@"testUnswizzle2"];
    
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base oneArgument:@"first"];
    XCTAssertTrue(times == 2);
    [FTSwizzler unswizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class];
    [base oneArgument:@"second"];
    XCTAssertTrue(times == 2);
}

- (void)testUnswizzleWithName{
    __block NSInteger times = 0;
    [FTSwizzler swizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class withBlock:^(NSString *first){
        times += 1;
    } named:@"testUnswizzleWithName1"];
    [FTSwizzler swizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class withBlock:^(NSString *first){
        times += 1;
    } named:@"testUnswizzleWithName2"];
    
    BaseSwizzlerClass *base = [BaseSwizzlerClass new];
    [base oneArgument:@"first"];
    XCTAssertTrue(times == 2);
    [FTSwizzler unswizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class named:@"testUnswizzleWithName1"];
    [base oneArgument:@"second"];
    XCTAssertTrue(times == 3);
    [FTSwizzler unswizzleSelector:@selector(oneArgument:) onClass:BaseSwizzlerClass.class named:@"testUnswizzleWithName2"];
    [base oneArgument:@"third"];
    XCTAssertTrue(times == 3);
}
- (void)testSwizzleWrongOriSelector{
    SEL wrongOriSelector = @selector(selector_ori_no_existed);

   XCTAssertThrows([FTSwizzler swizzleSelector:wrongOriSelector onClass:BaseSwizzlerClass.class withBlock:^(NSString *first){
   } named:@"testSwizzleWrongOriSelector"]);
}
- (void)testSwizzleExceedArgSelector{
    SEL exceedArgumentSelector = @selector(exceedArgument:second:third:fourth:);
    XCTAssertThrows([FTSwizzler swizzleSelector:exceedArgumentSelector onClass:BaseSwizzlerClass.class withBlock:^(NSString *first){
    } named:@"testSwizzleExceedArgSelector"]);
}
- (void)testSwizzleDelegate{
    self.sub = [SubSwizzlerClass new];
    SEL selector = @selector(baseSring:);
    self.delegate = self.sub;
    Class class = [FTSwizzler realDelegateClassFromSelector:selector proxy:self.delegate];
    __block NSInteger times = 0;
    if ([FTSwizzler realDelegateClass:class respondsToSelector:selector]) {
        [FTSwizzler swizzleSelector:selector
                            onClass:class
                          withBlock:^{
            times += 1;
        }
                              named:@"testSwizzleDelegate"];
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
        [FTSwizzler swizzleSelector:selector
                            onClass:class
                          withBlock:^{
            times += 1;
        }
                              named:@"testSwizzleNullDelegate"];
    }
    [self.sub baseSring:@"first"];
    XCTAssertTrue(times == 0);
}
@end
