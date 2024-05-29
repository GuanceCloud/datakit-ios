//
//  TestSessionDelegate.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/1/24.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "TestSessionDelegate.h"
@interface TestSessionDelegate()
@property (nonatomic, strong) XCTestExpectation *expectation;
@end
@implementation TestSessionDelegate
-(instancetype)initWithTestExpectation:(XCTestExpectation *)expectation{
    self = [super init];
    if(self){
        _expectation = expectation;
    }
    return self;
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [self.expectation fulfill];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    
}
@end
@interface TestSessionDelegate_NoCollectingMetrics()
@property (nonatomic, strong) XCTestExpectation *expectation;
@end
@implementation TestSessionDelegate_NoCollectingMetrics
-(instancetype)initWithTestExpectation:(XCTestExpectation *)expectation{
    self = [super init];
    if(self){
        _expectation = expectation;
    }
    return self;
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [self.expectation fulfill];
}
@end

@implementation  TestSessionDelegate_OnlyCollectingMetrics

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    
}

@end

@implementation TestSessionDelegate_None


@end

@implementation FTURLSessionCompleteTestDelegate

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    self.URLSessionTaskDidCompleteWithErrorCalledCount += 1;
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    self.URLSessionDataTaskDidReceiveDataCalledCount += 1;
}
@end

@implementation FTURLSessionNoCompleteTestDelegate

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    self.URLSessionDataTaskDidReceiveDataCalledCount += 1;
}
@end


@implementation FTURLSessionNoDidFinishCollectingMetrics


@end
