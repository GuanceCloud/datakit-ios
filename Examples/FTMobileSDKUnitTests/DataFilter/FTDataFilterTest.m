//
//  FTDataFilterTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/5/14.
//

#import <XCTest/XCTest.h>
#import "FTDataFilter.h"
#import "FTDataFilterManager.h"
#import "FTDataFilterPullRequest.h"
#import "FTHTTPClient.h"
#import "FTNetworkInfoManager.h"

typedef void(^FTDataFilterMockHTTPCompletion)(NSHTTPURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable error);

@interface FTDataFilterMockHTTPClient : FTHTTPClient
@property (nonatomic, strong) NSMutableArray<FTDataFilterMockHTTPCompletion> *completions;
- (void)completeRequestAtIndex:(NSUInteger)index responseObject:(id)responseObject;
- (void)completeRequestAtIndex:(NSUInteger)index rawString:(NSString *)rawString;
- (void)completeRequestAtIndex:(NSUInteger)index data:(NSData *)data;
@end

@implementation FTDataFilterMockHTTPClient

- (instancetype)init {
    self = [super init];
    if (self) {
        _completions = [NSMutableArray array];
    }
    return self;
}

- (void)sendRequest:(id<FTRequestProtocol>)request completion:(void (^)(NSHTTPURLResponse * _Nonnull, NSData * _Nullable, NSError * _Nullable))callback {
    if (callback) {
        [self.completions addObject:[callback copy]];
    }
}

- (void)completeRequestAtIndex:(NSUInteger)index responseObject:(id)responseObject {
    NSData *data = [NSJSONSerialization dataWithJSONObject:responseObject options:0 error:nil];
    [self completeRequestAtIndex:index data:data];
}

- (void)completeRequestAtIndex:(NSUInteger)index rawString:(NSString *)rawString {
    [self completeRequestAtIndex:index data:[rawString dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)completeRequestAtIndex:(NSUInteger)index data:(NSData *)data {
    if (index >= self.completions.count) {
        return;
    }
    NSURL *url = [NSURL URLWithString:@"http://example.com/v1/datakit/pull"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:nil headerFields:nil];
    self.completions[index](response, data, nil);
}

@end

@interface FTDataFilterTest : XCTestCase
@end

@implementation FTDataFilterTest

- (void)setUp {
    [super setUp];
    [[FTDataFilterManager sharedInstance] shutDown];
    [[FTDataFilterManager sharedInstance] setValue:[[FTHTTPClient alloc] init] forKey:@"httpClient"];
    [[FTNetworkInfoManager sharedInstance] clearUploadInfo];
}

- (void)tearDown {
    [[FTDataFilterManager sharedInstance] shutDown];
    [[FTDataFilterManager sharedInstance] setValue:[[FTHTTPClient alloc] init] forKey:@"httpClient"];
    [[FTNetworkInfoManager sharedInstance] clearUploadInfo];
    [super tearDown];
}

- (FTDataFilterManager *)dataFilterManagerWithMockClient:(FTDataFilterMockHTTPClient *)client {
    FTDataFilterManager *manager = [FTDataFilterManager sharedInstance];
    [manager setValue:client forKey:@"httpClient"];
    return manager;
}

- (void)configureDatakitURL:(NSString *)url {
    [FTNetworkInfoManager sharedInstance].setUploadURL(url, nil, nil);
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
}

- (void)configureDatawayURL:(NSString *)url token:(NSString *)token {
    [FTNetworkInfoManager sharedInstance].setUploadURL(nil, url, token);
    XCTAssertTrue([FTNetworkInfoManager sharedInstance].isNetworkConfigured);
}

- (BOOL)validateRemoteFiltersSchema:(NSDictionary *)response {
    id filters = response[@"filters"];
    if (![filters isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    NSDictionary *filtersDictionary = filters;
    for (NSString *category in @[@"logging", @"rum"]) {
        id rules = filtersDictionary[category];
        if (!rules) {
            continue;
        }
        if (![rules isKindOfClass:NSArray.class]) {
            return NO;
        }
        for (id rule in rules) {
            if (![rule isKindOfClass:NSString.class]) {
                return NO;
            }
        }
    }
    return YES;
}

- (void)testRemoteDataFilterPullSchemaWithAccessServerURL {
    NSDictionary *environment = NSProcessInfo.processInfo.environment;
    NSString *datakitURLString = environment[@"ACCESS_SERVER_URL"];
    if (datakitURLString.length == 0) {
        XCTSkip(@"ACCESS_SERVER_URL is required for the real DataKit filter pull schema test.");
        return;
    }
    NSURL *datakitURL = [NSURL URLWithString:datakitURLString];
    if (datakitURL.scheme.length == 0 || datakitURL.host.length == 0) {
        XCTSkip(@"ACCESS_SERVER_URL must be a valid absolute DataKit URL.");
        return;
    }

    [self configureDatakitURL:datakitURLString];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Pull real DataKit filter schema"];
    __block NSHTTPURLResponse *receivedResponse = nil;
    __block NSData *receivedData = nil;
    __block NSError *receivedError = nil;

    FTHTTPClient *httpClient = [[FTHTTPClient alloc] init];
    FTDataFilterPullRequest *request = [[FTDataFilterPullRequest alloc] init];
    [httpClient sendRequest:request completion:^(NSHTTPURLResponse * _Nonnull httpResponse, NSData * _Nullable data, NSError * _Nullable error) {
        receivedResponse = httpResponse;
        receivedData = data;
        receivedError = error;
        [expectation fulfill];
    }];

    [self waitForExpectations:@[expectation] timeout:35];
    XCTAssertNil(receivedError);
    if (receivedError) {
        return;
    }
    if (receivedResponse.statusCode == 403) {
        XCTSkip(@"ACCESS_SERVER_URL returned 403 for DataKit filter pull; this environment does not allow schema verification.");
        return;
    }
    XCTAssertEqual(receivedResponse.statusCode, 200);
    XCTAssertTrue(receivedData.length > 0);
    if (receivedResponse.statusCode != 200 || receivedData.length == 0) {
        return;
    }

    NSError *jsonError = nil;
    id responseObject = [NSJSONSerialization JSONObjectWithData:receivedData options:0 error:&jsonError];
    XCTAssertNil(jsonError);
    if (jsonError) {
        return;
    }
    XCTAssertTrue([responseObject isKindOfClass:NSDictionary.class]);
    if (![responseObject isKindOfClass:NSDictionary.class]) {
        return;
    }
    NSDictionary *responseDictionary = responseObject;
    BOOL hasValidFilterSchema = [self validateRemoteFiltersSchema:responseDictionary];
    XCTAssertTrue(hasValidFilterSchema);
    if (!hasValidFilterSchema) {
        return;
    }

    FTDataFilterMockHTTPClient *client = [FTDataFilterMockHTTPClient new];
    FTDataFilterManager *manager = [self dataFilterManagerWithMockClient:client];
    [manager enable:YES localFilters:@{} updateInterval:30];
    XCTAssertEqual(client.completions.count, 1u);
    [client completeRequestAtIndex:0 data:receivedData];
    XCTAssertTrue(manager.shouldDisableServerFilter);
}

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

- (void)testMatchesCliutilsRegexListExamples {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{ abc match ['a.*'] }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"ios_log"
                                           tags:@{}
                                         fields:@{@"abc": @"abc123"}]);
    
    FTDataFilter *invalidFilter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[
            @"{ abc notmatch []}",
            @"{ abc match ['g(-z]+ng wrong regex']}"
        ]
    }];
    XCTAssertFalse([invalidFilter isMatchedWithCategory:@"logging"
                                                 source:@"ios_log"
                                                   tags:@{}
                                                 fields:@{@"abc": @"abc123"}]);
}

- (void)testMatchesCliutilsRegexOrExamples {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{ abc notmatch ['a.*'] or xyz match ['.*'] }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"ios_log"
                                           tags:@{@"xyz": @"def"}
                                         fields:@{@"abc": @"abc123"}]);
}

- (void)testMatchesCliutilsReFunctionAndNestedOrExample {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"rum": @[@"{ service = re(\".*\") AND (f1 in [\"1\", \"2\", \"3\"] OR t1 match ['def.*'] OR t2 notmatch ['def.*']) }"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"resource"
                                           tags:@{@"service": @"api"}
                                         fields:@{@"f1": @"2"}]);
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"resource"
                                           tags:@{@"service": @"api"}
                                         fields:@{@"t1": @"def456"}]);
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"resource"
                                           tags:@{@"service": @"api"}
                                         fields:@{@"t2": @"abc"}]);
    XCTAssertFalse([filter isMatchedWithCategory:@"rum"
                                          source:@"resource"
                                            tags:@{@"service": @"api"}
                                          fields:@{@"t2": @"def456"}]);
}

- (void)testMatchesCliutilsNotInAndSymbolicOrExample {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"rum": @[@"{abc notin [1.1,1.2,1.3] and (a > 1 || c< 0)}"]
    }];
    NSDictionary *matchedFields = @{@"abc": @4, @"a": @(-1), @"c": @(-2)};
    NSDictionary *unmatchedFields = @{@"abc": @4, @"a": @(-1), @"c": @2};
    XCTAssertTrue([filter isMatchedWithCategory:@"rum"
                                         source:@"resource"
                                           tags:@{}
                                         fields:matchedFields]);
    XCTAssertFalse([filter isMatchedWithCategory:@"rum"
                                          source:@"resource"
                                            tags:@{}
                                          fields:unmatchedFields]);
}

- (void)testMatchesCliutilsReFunctionExamples {
    FTDataFilter *filter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{host = re(\"^nginx_.*$\")}"]
    }];
    XCTAssertTrue([filter isMatchedWithCategory:@"logging"
                                         source:@"ios_log"
                                           tags:@{}
                                         fields:@{@"host": @"nginx_abc"}]);
    
    FTDataFilter *backtickFilter = [[FTDataFilter alloc] initWithFilters:@{
        @"logging": @[@"{host = re(`nginx_*`)}"]
    }];
    XCTAssertFalse([backtickFilter isMatchedWithCategory:@"logging"
                                                  source:@"ios_log"
                                                    tags:@{}
                                                  fields:@{@"host": @"abcdef"}]);
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

- (void)testRemoteCallbackAfterShutdownDoesNotCommitState {
    [self configureDatakitURL:@"http://datakit-a.example"];
    FTDataFilterMockHTTPClient *client = [FTDataFilterMockHTTPClient new];
    FTDataFilterManager *manager = [self dataFilterManagerWithMockClient:client];
    [manager enable:YES localFilters:@{} updateInterval:30];
    XCTAssertEqual(client.completions.count, 1u);
    
    [manager shutDown];
    [client completeRequestAtIndex:0 responseObject:@{
        @"filters": @{@"logging": @[@"{ status = 'old_remote' }"]}
    }];
    
    XCTAssertFalse(manager.shouldDisableServerFilter);
    XCTAssertFalse([manager isFilteredWithCategory:@"logging"
                                            source:@"ios_log"
                                              uuid:@"uuid"
                                              tags:@{@"status": @"old_remote"}
                                            fields:@{}]);
}

- (void)testRemoteCallbackFromPreviousGenerationDoesNotOverrideReinit {
    [self configureDatakitURL:@"http://datakit-a.example"];
    FTDataFilterMockHTTPClient *client = [FTDataFilterMockHTTPClient new];
    FTDataFilterManager *manager = [self dataFilterManagerWithMockClient:client];
    [manager enable:YES localFilters:@{} updateInterval:30];
    XCTAssertEqual(client.completions.count, 1u);
    
    [manager enable:YES localFilters:@{@"logging": @[@"{ status = 'local_new' }"]} updateInterval:30];
    XCTAssertEqual(client.completions.count, 2u);
    
    [client completeRequestAtIndex:0 responseObject:@{
        @"filters": @{@"logging": @[@"{ status = 'old_remote' }"]}
    }];
    XCTAssertFalse(manager.shouldDisableServerFilter);
    XCTAssertFalse([manager isFilteredWithCategory:@"logging"
                                            source:@"ios_log"
                                              uuid:@"uuid"
                                              tags:@{@"status": @"old_remote"}
                                            fields:@{}]);
    XCTAssertTrue([manager isFilteredWithCategory:@"logging"
                                           source:@"ios_log"
                                             uuid:@"uuid"
                                             tags:@{@"status": @"local_new"}
                                           fields:@{}]);
    
    [client completeRequestAtIndex:1 responseObject:@{
        @"filters": @{@"logging": @[@"{ status = 'new_remote' }"]}
    }];
    XCTAssertTrue(manager.shouldDisableServerFilter);
    XCTAssertTrue([manager isFilteredWithCategory:@"logging"
                                           source:@"ios_log"
                                             uuid:@"uuid"
                                             tags:@{@"status": @"new_remote"}
                                           fields:@{}]);
}

- (void)testForceRefreshDiscardsPreviousDatakitEndpointResponse {
    [self configureDatakitURL:@"http://datakit-a.example"];
    FTDataFilterMockHTTPClient *client = [FTDataFilterMockHTTPClient new];
    FTDataFilterManager *manager = [self dataFilterManagerWithMockClient:client];
    [manager enable:YES localFilters:@{} updateInterval:30];
    XCTAssertEqual(client.completions.count, 1u);
    
    [self configureDatakitURL:@"http://datakit-b.example"];
    [manager updateRemoteFilterIfNeededWithForce:YES];
    XCTAssertEqual(client.completions.count, 2u);
    
    [client completeRequestAtIndex:0 responseObject:@{
        @"filters": @{@"logging": @[@"{ status = 'old_endpoint' }"]}
    }];
    XCTAssertFalse(manager.shouldDisableServerFilter);
    XCTAssertFalse([manager isFilteredWithCategory:@"logging"
                                            source:@"ios_log"
                                              uuid:@"uuid"
                                              tags:@{@"status": @"old_endpoint"}
                                            fields:@{}]);
    
    [client completeRequestAtIndex:1 responseObject:@{
        @"filters": @{@"logging": @[@"{ status = 'new_endpoint' }"]}
    }];
    XCTAssertTrue(manager.shouldDisableServerFilter);
    XCTAssertTrue([manager isFilteredWithCategory:@"logging"
                                           source:@"ios_log"
                                             uuid:@"uuid"
                                             tags:@{@"status": @"new_endpoint"}
                                           fields:@{}]);
}

- (void)testForceRefreshDiscardsPreviousDatawayTokenResponse {
    [self configureDatawayURL:@"http://dataway.example" token:@"token-a"];
    FTDataFilterMockHTTPClient *client = [FTDataFilterMockHTTPClient new];
    FTDataFilterManager *manager = [self dataFilterManagerWithMockClient:client];
    [manager enable:YES localFilters:@{} updateInterval:30];
    XCTAssertEqual(client.completions.count, 1u);
    
    [self configureDatawayURL:@"http://dataway.example" token:@"token-b"];
    [manager updateRemoteFilterIfNeededWithForce:YES];
    XCTAssertEqual(client.completions.count, 2u);
    
    [client completeRequestAtIndex:0 responseObject:@{
        @"filters": @{@"logging": @[@"{ status = 'old_token' }"]}
    }];
    XCTAssertFalse(manager.shouldDisableServerFilter);
    XCTAssertFalse([manager isFilteredWithCategory:@"logging"
                                            source:@"ios_log"
                                              uuid:@"uuid"
                                              tags:@{@"status": @"old_token"}
                                            fields:@{}]);
    
    [client completeRequestAtIndex:1 responseObject:@{
        @"filters": @{@"logging": @[@"{ status = 'new_token' }"]}
    }];
    XCTAssertTrue(manager.shouldDisableServerFilter);
    XCTAssertTrue([manager isFilteredWithCategory:@"logging"
                                           source:@"ios_log"
                                             uuid:@"uuid"
                                             tags:@{@"status": @"new_token"}
                                           fields:@{}]);
}

- (void)testInvalidRemoteResponseDoesNotDisableServerFilter {
    [self configureDatakitURL:@"http://datakit-a.example"];
    FTDataFilterMockHTTPClient *client = [FTDataFilterMockHTTPClient new];
    FTDataFilterManager *manager = [self dataFilterManagerWithMockClient:client];
    [manager enable:YES localFilters:@{} updateInterval:30];
    XCTAssertEqual(client.completions.count, 1u);
    
    [client completeRequestAtIndex:0 rawString:@"not-json"];
    XCTAssertFalse(manager.shouldDisableServerFilter);
    
    [manager updateRemoteFilterIfNeededWithForce:YES];
    XCTAssertEqual(client.completions.count, 2u);
    [client completeRequestAtIndex:1 responseObject:@{@"filters": @"bad-schema"}];
    XCTAssertFalse(manager.shouldDisableServerFilter);
}

- (void)testInvalidLocalFiltersDoNotCrash {
    FTDataFilterManager *manager = [FTDataFilterManager sharedInstance];
    id invalidFilters = @"bad-filters";
    XCTAssertNoThrow([manager enable:YES
                        localFilters:(NSDictionary<NSString *,NSArray<NSString *> *> *)invalidFilters
                      updateInterval:30]);
    XCTAssertFalse([manager isFilteredWithCategory:@"logging"
                                            source:@"ios_log"
                                              uuid:@"uuid"
                                              tags:@{@"status": @"anything"}
                                            fields:@{}]);
}

- (void)testFilteringWhileEnableAndShutdownDoesNotCrash {
    FTDataFilterManager *manager = [FTDataFilterManager sharedInstance];
    NSDictionary *filters = @{@"logging": @[@"{ status = 'drop' }"]};
    dispatch_queue_t queue = dispatch_queue_create("com.ft.data-filter.concurrent-test", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    for (NSInteger index = 0; index < 100; index++) {
        dispatch_group_async(group, queue, ^{
            @autoreleasepool {
                [manager enable:YES localFilters:filters updateInterval:30];
            }
        });
        dispatch_group_async(group, queue, ^{
            @autoreleasepool {
                [manager isFilteredWithCategory:@"logging"
                                         source:@"ios_log"
                                           uuid:@"uuid"
                                           tags:@{@"status": @"drop"}
                                         fields:@{}];
            }
        });
        dispatch_group_async(group, queue, ^{
            @autoreleasepool {
                [manager shutDown];
            }
        });
    }
    
    XCTAssertEqual(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC))), 0);
    [manager enable:YES localFilters:filters updateInterval:30];
    XCTAssertTrue([manager isFilteredWithCategory:@"logging"
                                           source:@"ios_log"
                                             uuid:@"uuid"
                                             tags:@{@"status": @"drop"}
                                           fields:@{}]);
    [manager shutDown];
    XCTAssertFalse([manager isFilteredWithCategory:@"logging"
                                            source:@"ios_log"
                                              uuid:@"uuid"
                                              tags:@{@"status": @"drop"}
                                            fields:@{}]);
}

@end
