//
//  FTNodesFlattenerTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/6/8.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTNodesFlattener.h"
#import "FTViewAttributes.h"
#import "FTViewTreeSnapshot.h"

@interface FTNodesFlattenerTestAttributes : FTViewAttributes
@property (nonatomic, assign) BOOL testHasAnyAppearance;
@property (nonatomic, assign) BOOL testTranslucent;
@end

@implementation FTNodesFlattenerTestAttributes

- (BOOL)hasAnyAppearance {
    return self.testHasAnyAppearance;
}

- (BOOL)isTranslucent {
    return self.testTranslucent;
}

@end

@interface FTNodesFlattenerTestNode : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, copy) NSString *name;
+ (instancetype)nodeWithName:(NSString *)name
                       frame:(CGRect)frame
            hasAnyAppearance:(BOOL)hasAnyAppearance
               isTranslucent:(BOOL)isTranslucent;
@end

@implementation FTNodesFlattenerTestNode

+ (instancetype)nodeWithName:(NSString *)name
                       frame:(CGRect)frame
            hasAnyAppearance:(BOOL)hasAnyAppearance
               isTranslucent:(BOOL)isTranslucent {
    FTNodesFlattenerTestAttributes *attributes = [FTNodesFlattenerTestAttributes new];
    attributes.testHasAnyAppearance = hasAnyAppearance;
    attributes.testTranslucent = isTranslucent;

    FTNodesFlattenerTestNode *node = [FTNodesFlattenerTestNode new];
    node.name = name;
    node.wireframeRect = frame;
    node.attributes = attributes;
    return node;
}

- (NSArray<FTSRWireframe *> *)buildWireframesWithBuilder:(FTSessionReplayWireframesBuilder *)builder {
    return @[];
}

@end

@interface FTNodesFlattenerTests : XCTestCase
@property (nonatomic, strong) FTNodesFlattener *flattener;
@end

@implementation FTNodesFlattenerTests

- (void)setUp {
    [super setUp];
    self.flattener = [FTNodesFlattener new];
}

- (void)tearDown {
    self.flattener = nil;
    [super tearDown];
}

- (void)testFiltersNodesOutsideViewport {
    FTNodesFlattenerTestNode *visible = [self node:@"visible" frame:CGRectMake(10, 10, 20, 20)];
    FTNodesFlattenerTestNode *outside = [self node:@"outside" frame:CGRectMake(120, 120, 20, 20)];

    NSArray *flattened = [self flatten:@[visible, outside]];

    XCTAssertEqualObjects([self namesOfNodes:flattened], (@[@"visible"]));
}

- (void)testForegroundOpaqueSiblingOccludesBackgroundSibling {
    FTNodesFlattenerTestNode *background = [self node:@"background" frame:CGRectMake(10, 10, 40, 40)];
    FTNodesFlattenerTestNode *foreground = [self node:@"foreground" frame:CGRectMake(10, 10, 40, 40)];

    NSArray *flattened = [self flatten:@[background, foreground]];

    XCTAssertEqualObjects([self namesOfNodes:flattened], (@[@"foreground"]));
}

- (void)testTranslucentForegroundSiblingDoesNotOccludeBackgroundSibling {
    FTNodesFlattenerTestNode *background = [self node:@"background" frame:CGRectMake(10, 10, 40, 40)];
    FTNodesFlattenerTestNode *foreground = [FTNodesFlattenerTestNode nodeWithName:@"foreground"
                                                                            frame:CGRectMake(10, 10, 40, 40)
	                                                                 hasAnyAppearance:YES
	                                                                    isTranslucent:YES];

    NSArray *flattened = [self flatten:@[background, foreground]];

    XCTAssertEqualObjects([self namesOfNodes:flattened], (@[@"background", @"foreground"]));
}

- (void)testNodeWithoutAppearanceDoesNotOccludeButIsKept {
    FTNodesFlattenerTestNode *background = [self node:@"background" frame:CGRectMake(10, 10, 40, 40)];
    FTNodesFlattenerTestNode *foreground = [FTNodesFlattenerTestNode nodeWithName:@"foreground"
                                                                            frame:CGRectMake(10, 10, 40, 40)
	                                                                 hasAnyAppearance:NO
	                                                                    isTranslucent:NO];

    NSArray *flattened = [self flatten:@[background, foreground]];

    XCTAssertEqualObjects([self namesOfNodes:flattened], (@[@"background", @"foreground"]));
}

- (void)testOpaqueParentDoesNotOccludeChildRecordedAfterParent {
    FTNodesFlattenerTestNode *parent = [self node:@"parent" frame:CGRectMake(0, 0, 100, 100)];
    FTNodesFlattenerTestNode *child = [self node:@"child" frame:CGRectMake(10, 10, 20, 20)];

    NSArray *flattened = [self flatten:@[parent, child]];

    XCTAssertEqualObjects([self namesOfNodes:flattened], (@[@"parent", @"child"]));
}

- (void)testOutputKeepsSnapshotOrderForVisibleNodes {
    FTNodesFlattenerTestNode *first = [self node:@"first" frame:CGRectMake(0, 0, 10, 10)];
    FTNodesFlattenerTestNode *second = [self node:@"second" frame:CGRectMake(20, 20, 10, 10)];
    FTNodesFlattenerTestNode *third = [self node:@"third" frame:CGRectMake(40, 40, 10, 10)];

    NSArray *flattened = [self flatten:@[first, second, third]];

    XCTAssertEqualObjects([self namesOfNodes:flattened], (@[@"first", @"second", @"third"]));
}

- (FTNodesFlattenerTestNode *)node:(NSString *)name frame:(CGRect)frame {
    return [FTNodesFlattenerTestNode nodeWithName:name
                                            frame:frame
                                 hasAnyAppearance:YES
                                    isTranslucent:NO];
}

- (NSArray *)flatten:(NSArray<id<FTSRNodeWireframesBuilder>> *)nodes {
    FTViewTreeSnapshot *snapshot = [FTViewTreeSnapshot new];
    snapshot.viewportSize = CGSizeMake(100, 100);
    snapshot.nodes = nodes;
    return [self.flattener flattenNodes:snapshot];
}

- (NSArray<NSString *> *)namesOfNodes:(NSArray<FTNodesFlattenerTestNode *> *)nodes {
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:nodes.count];
    for (FTNodesFlattenerTestNode *node in nodes) {
        [names addObject:node.name];
    }
    return names;
}

@end
