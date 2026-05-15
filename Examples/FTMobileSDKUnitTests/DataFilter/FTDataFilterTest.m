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

- (void)testSupportsBacktickKeysBracketMatchAndParenthesizedCondition {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{  `source` in [ 'df_rum_ios_log' ]  and ( `status` match [ '^ok$' ] )}"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"df_rum_ios_log"
                                           tags:@{@"status": @"ok"}
                                         fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"df_rum_ios_log"
                                            tags:@{@"status": @"error"}
                                          fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"other_source"
                                            tags:@{@"status": @"ok"}
                                          fields:@{}]);
}

- (void)testSupportsBacktickKeysBracketNotmatchAndParenthesizedCondition {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{  `source` in [ 'df_rum_ios_log' ]  and ( `status` notmatch [ '^ok$' ] )}"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"df_rum_ios_log"
                                           tags:@{@"status": @"error"}
                                         fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"df_rum_ios_log"
                                            tags:@{@"status": @"ok"}
                                          fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"other_source"
                                            tags:@{@"status": @"error"}
                                          fields:@{}]);
}

- (void)testSupportsBacktickKeysBracketNotinAndParenthesizedCondition {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{  `source` in [ 'df_rum_ios_log' ]  and ( `status` notin [ 'ok' ] )}"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"df_rum_ios_log"
                                           tags:@{@"status": @"error"}
                                         fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"df_rum_ios_log"
                                            tags:@{@"status": @"ok"}
                                          fields:@{}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"other_source"
                                            tags:@{@"status": @"error"}
                                          fields:@{}]);
}

- (void)testOperatorsAreCaseInsensitive {
    NSArray<NSString *> *rules = @[
        @"{ `source` IN [ 'df_rum_ios_log' ] and `status` MATCH [ 'ok' ] }",
        @"{ `source` IN [ 'df_rum_ios_log' ] and `status` NOTIN [ 'error' ] }",
        @"{ `source` IN [ 'df_rum_ios_log' ] and `status` NOTMATCH [ 'error' ] }"
    ];
    for (NSString *rule in rules) {
        FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{@"logging": @[rule]}];
        XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                             source:@"df_rum_ios_log"
                                               tags:@{@"status": @"ok"}
                                             fields:@{}]);
    }
}

- (void)testMatchesDataKitLoggingMessagePatternExample {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{ source = 'ios_log' and message match ['timeout.*'] }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"ios_log"
                                           tags:@{}
                                         fields:@{@"message": @"timeout while uploading"}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"ios_log"
                                            tags:@{}
                                          fields:@{@"message": @"upload completed"}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"other"
                                            tags:@{}
                                          fields:@{@"message": @"timeout while uploading"}]);
}

- (void)testMatchesDataKitResourceDurationExample {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"rum": @[@"{ source = 'resource' and duration >= 1000000000 }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"resource"
                                           tags:@{}
                                         fields:@{@"duration": @1000000000}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"rum"
                                          source:@"resource"
                                            tags:@{}
                                          fields:@{@"duration": @999999999}]);
}

- (void)testMatchesDataKitErrorMessagePatternExample {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"rum": @[@"{ source = 'error' and error_message match ['.*password.*'] }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"error"
                                           tags:@{}
                                         fields:@{@"error_message": @"password should be redacted"}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"rum"
                                          source:@"error"
                                            tags:@{}
                                          fields:@{@"error_message": @"token should be redacted"}]);
}

- (void)testInvalidRegexInvalidatesRule {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{ status = 'error' and message =~ '[' }"]
    }];
    XCTAssertFalse([filter isMatchedWithCategory:@"logging"
                                          source:@"df_rum_ios_log"
                                            tags:@{@"status": @"error"}
                                          fields:@{@"message": @"socket reset"}]);
}

@end
