//
//  FTResourceTypeTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/12/23.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTResourceContentModel.h"

@interface FTResourceContentModel()

- (NSString *)resourceTypeWithResponse:(NSURLResponse *)response;
- (nullable NSString *)resourceTypeWithRequest:(NSURLRequest *)request;

@end

@interface FTResourceTypeTest : XCTestCase

@end

@implementation FTResourceTypeTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/// Test that POST/PUT/DELETE methods return "native"
- (void)testResourceTypeWithRequest_NativeMethods {
    FTResourceContentModel *model = [FTResourceContentModel new];
    NSArray<NSString *> *nativeMethods = @[@"POST", @"PUT", @"DELETE", @"post", @"Put", @"delete"]; // Cover case sensitivity
    for (NSString *method in nativeMethods) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://test.com"]];
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        mutableRequest.HTTPMethod = method;
        
        NSString *type = [model resourceTypeWithRequest:mutableRequest];
        XCTAssertEqualObjects(type, @"native", @"HTTP Method %@ should return 'native'", method);
    }
}

/// Test that non-Native methods (GET/HEAD, etc.) return nil
- (void)testResourceTypeWithRequest_NonNativeMethods {
    FTResourceContentModel *model = [FTResourceContentModel new];
    NSArray<NSString *> *nonNativeMethods = @[@"GET", @"HEAD", @"OPTIONS", @"PATCH"];
    for (NSString *method in nonNativeMethods) {
        NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://test.com"]];
        mutableRequest.HTTPMethod = method;
        
        NSString *type = [model resourceTypeWithRequest:mutableRequest];
        XCTAssertNil(type, @"HTTP Method %@ should return nil", method);
    }
}

/// Test case where HTTPMethod is nil
- (void)testResourceTypeWithRequest_NilMethod {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://test.com"]];
    FTResourceContentModel *model = [FTResourceContentModel new];
   
    NSString *type = [model resourceTypeWithRequest:request];

    XCTAssertNil(type, @"Should return nil when HTTPMethod is nil");
}

#pragma mark - 3. Test resourceTypeWithResponse method
/// Test that MIME Type starting with image/* returns "image"
- (void)testResourceTypeWithResponse_ImageType {
    FTResourceContentModel *model = [FTResourceContentModel new];
    NSArray<NSString *> *imageMIMETypes = @[@"image/png", @"image/jpeg", @"image/gif", @"image/webp"];
    for (NSString *mimeType in imageMIMETypes) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                 statusCode:200
                                                                HTTPVersion:@"1.1"
                                                               headerFields:@{@"Content-Type": mimeType}];
        NSString *type = [model resourceTypeWithResponse:response];
        XCTAssertEqualObjects(type, @"image", @"MIME Type %@ should return 'image'", mimeType);
    }
}

/// Test that MIME Type for video/audio returns "media"
- (void)testResourceTypeWithResponse_MediaType {
    FTResourceContentModel *model = [FTResourceContentModel new];
    NSArray<NSString *> *mediaMIMETypes = @[@"video/mp4", @"audio/mp3", @"video/mpeg", @"audio/wav"];
    for (NSString *mimeType in mediaMIMETypes) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                 statusCode:200
                                                                HTTPVersion:@"1.1"
                                                               headerFields:@{@"Content-Type": mimeType}];
        NSString *type = [model resourceTypeWithResponse:response];
        XCTAssertEqualObjects(type, @"media", @"MIME Type %@ should return 'media'", mimeType);
    }
}

/// Test that MIME Type starting with font/* returns "font"
- (void)testResourceTypeWithResponse_FontType {
    FTResourceContentModel *model = [FTResourceContentModel new];
    NSArray<NSString *> *fontMIMETypes = @[@"font/ttf", @"font/otf", @"font/woff", @"font/woff2"];
    for (NSString *mimeType in fontMIMETypes) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                 statusCode:200
                                                                HTTPVersion:@"1.1"
                                                               headerFields:@{@"Content-Type": mimeType}];
        NSString *type = [model resourceTypeWithResponse:response];
        XCTAssertEqualObjects(type, @"font", @"MIME Type %@ should return 'font'", mimeType);
    }
}

/// Test that MIME Type text/css returns "css"
- (void)testResourceTypeWithResponse_CSStyle {
    FTResourceContentModel *model = [FTResourceContentModel new];
    NSArray<NSString *> *cssMIMETypes = @[@"text/css", @"text/css;charset=utf-8", @"text/css; version=1.0"]; // Cases with parameters
    for (NSString *mimeType in cssMIMETypes) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                 statusCode:200
                                                                HTTPVersion:@"1.1"
                                                               headerFields:@{@"Content-Type": mimeType}];
        NSString *type = [model resourceTypeWithResponse:response];
        XCTAssertEqualObjects(type, @"css", @"MIME Type %@ should return 'css'", mimeType);
    }
}

/// Test that MIME Type text/javascript returns "js"
- (void)testResourceTypeWithResponse_JSType {
    FTResourceContentModel *model = [FTResourceContentModel new];
    NSArray<NSString *> *jsMIMETypes = @[@"text/javascript", @"text/javascript;charset=utf-8", @"text/javascript; defer"];
    for (NSString *mimeType in jsMIMETypes) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                 statusCode:200
                                                                HTTPVersion:@"1.1"
                                                               headerFields:@{@"Content-Type": mimeType}];
        NSString *type = [model resourceTypeWithResponse:response];
        XCTAssertEqualObjects(type, @"js", @"MIME Type %@ should return 'js'", mimeType);
    }
}

/// Test empty/invalid format MIME Type returns "native"
- (void)testResourceTypeWithResponse_InvalidMIMEType {
    FTResourceContentModel *model = [FTResourceContentModel new];
    // Scenario 1: Empty MIME Type
    NSHTTPURLResponse *emptyMIMETypeResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                           statusCode:200
                                                                          HTTPVersion:@"1.1"
                                                                         headerFields:@{}];
    NSString *emptyType = [model resourceTypeWithResponse:emptyMIMETypeResponse];
    XCTAssertEqualObjects(emptyType, @"native", @"Empty MIME Type should return 'native'");
    
    // Scenario 2: MIME Type without / separator
    NSHTTPURLResponse *invalidFormatResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                              statusCode:200
                                                                             HTTPVersion:@"1.1"
                                                                            headerFields:@{@"Content-Type": @"applicationjson"}];
    NSString *invalidFormatType = [model resourceTypeWithResponse:invalidFormatResponse];
    XCTAssertEqualObjects(invalidFormatType, @"native", @"Invalid format MIME Type should return 'native'");
    
    // Scenario 3: Unmatched MIME Type (e.g., application/json)
    NSHTTPURLResponse *otherMIMETypeResponse = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                             statusCode:200
                                                                            HTTPVersion:@"1.1"
                                                                           headerFields:@{@"Content-Type": @"application/json"}];
    NSString *otherType = [model resourceTypeWithResponse:otherMIMETypeResponse];
    XCTAssertEqualObjects(otherType, @"native", @"Unmatched MIME Type should return 'native'");
}

#pragma mark - 4. Test resourceType priority in initialization method
/// Test that "native" is returned first when request meets Native criteria (ignoring response)
- (void)testInit_ResourceType_Priority_Request {
    // Construct POST request (meets Native criteria)
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://test.com"]];
    request.HTTPMethod = @"POST";
    
    // Construct image-type response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                 statusCode:200
                                                                HTTPVersion:@"1.1"
                                                               headerFields:@{@"Content-Type": @"image/png"}];
    
    FTResourceContentModel *model = [[FTResourceContentModel alloc] initWithRequest:request response:response data:nil error:nil];
    XCTAssertEqualObjects(model.resourceType, @"native", @"Should return 'native' first when request meets Native criteria");
}

/// Test that image is returned from response when request does not meet criteria
- (void)testInit_ResourceType_Priority_Response {
    // Construct GET request (does not meet Native criteria)
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://test.com"]];
    request.HTTPMethod = @"GET";
    
    // Construct image-type response
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://test.com"]
                                                                 statusCode:200
                                                                HTTPVersion:@"1.1"
                                                               headerFields:@{@"Content-Type": @"image/png"}];
    
    FTResourceContentModel *model = [[FTResourceContentModel alloc] initWithRequest:request response:response data:nil error:nil];
    XCTAssertEqualObjects(model.resourceType, @"image", @"Should take 'image' type from response when request does not meet criteria");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
