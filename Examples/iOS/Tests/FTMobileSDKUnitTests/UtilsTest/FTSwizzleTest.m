//
//  FTSwizzleTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/19.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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
@interface FTSwizzleTest : XCTestCase

@end

@implementation FTSwizzleTest

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
