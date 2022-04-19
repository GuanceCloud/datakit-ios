//
//  FTSwizzlerTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/19.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTSwizzle.h"
@interface BaseClass : NSObject
- (NSString *)oriInstanceMethodToSwizzle;
- (NSString *)altInstanceMethodToSwizzle;
+ (NSString *)oriClassMethodToSwizzle;
+ (NSString *)altClassMethodToSwizzle;
@end
@implementation BaseClass
- (NSString *)oriInstanceMethodToSwizzle{
    return @"instanceMethodToSwizzle";
}
- (NSString *)altInstanceMethodToSwizzle{
    return @"altInstanceMethodToSwizzle";
}
+ (NSString *)oriClassMethodToSwizzle{
    return @"oriClassMethodToSwizzle";
}
+ (NSString *)altClassMethodToSwizzle{
    return @"altClassMethodToSwizzle";
}
@end
@interface FTSwizzlerTest : XCTestCase

@end

@implementation FTSwizzlerTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testSwizzlerInstanceMethod{
    NSError *error = NULL;
    BOOL success = [BaseClass ft_swizzleMethod:@selector(oriInstanceMethodToSwizzle) withMethod:@selector(altInstanceMethodToSwizzle) error:&error];
    ;
    XCTAssertTrue(success);
    
    BaseClass *base = [BaseClass new];
    XCTAssertTrue([[base oriInstanceMethodToSwizzle] isEqualToString:@"altInstanceMethodToSwizzle"]);
}
- (void)testSwizzlerClassMethod{
    NSError *error = NULL;
    BOOL success = [BaseClass ft_swizzleClassMethod:@selector(oriClassMethodToSwizzle) withClassMethod:@selector(altClassMethodToSwizzle) error:&error];
    XCTAssertTrue(success);
    
    XCTAssertTrue([[BaseClass oriClassMethodToSwizzle] isEqualToString:@"altClassMethodToSwizzle"]);
}
- (void)testSwizzlerWrongOriSelector{
    SEL wrongOriSelector = @selector(selector_ori_no_existed);
    NSError *error = NULL;
    BOOL success = [BaseClass ft_swizzleMethod:wrongOriSelector withMethod:@selector(altInstanceMethodToSwizzle) error:&error];
    ;
    XCTAssertTrue(error && success==NO);
}
- (void)testSwizzlerWrongAltSelector{
    SEL wrongAltSelector = @selector(selector_alt_no_existed);
    NSError *error = NULL;
    BOOL success = [BaseClass ft_swizzleMethod:@selector(oriInstanceMethodToSwizzle) withMethod:wrongAltSelector error:&error];
    ;
    XCTAssertTrue(error && success==NO);
}
@end
