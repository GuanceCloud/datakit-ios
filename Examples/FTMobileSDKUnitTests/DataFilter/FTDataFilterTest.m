//
//  FTDataFilterTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/5/14.
//

#import <XCTest/XCTest.h>
#import "FTDataFilter.h"

@interface FTDataFilterTest : XCTestCase
@end

@implementation FTDataFilterTest

- (void)testMatchesSourceAndTag {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{ source = 'df_rum_ios_log' and status = 'error' }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"df_rum_ios_log"
                                           tags:@{@"status": @"error"}
                                         fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"df_rum_ios_log"
                                            tags:@{@"status": @"info"}
                                          fields:@{}]);
}

- (void)testMatchesOrAndNumericComparison {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"rum": @[@"{ source = 'resource' and duration >= 1000 or app_id = 'blocked' }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"resource"
                                           tags:@{}
                                         fields:@{@"duration": @1000}]);
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"view"
                                           tags:@{@"app_id": @"blocked"}
                                         fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"rum"
                                          source:@"resource"
                                            tags:@{}
                                          fields:@{@"duration": @999}]);
}

- (void)testSupportsInAndRegex {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{ status in ('error','critical') and message =~ 'timeout|reset' }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"df_rum_ios_log"
                                           tags:@{@"status": @"critical"}
                                         fields:@{@"message": @"socket reset"}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"df_rum_ios_log"
                                            tags:@{@"status": @"info"}
                                          fields:@{@"message": @"socket reset"}]);
}

@end
