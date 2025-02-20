//
//  TestSessionDelegate.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/1/24.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "TestSessionDelegate.h"
@interface TestSessionDelegate()
@property (nonatomic, copy) Completion completionHandler;
@end
@implementation TestSessionDelegate
-(instancetype)initWithCompletionHandler:(Completion)completionHandler{
    self = [super init];
    if(self){
        _completionHandler = completionHandler;
    }
    return self;
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if(self.completionHandler){
        self.completionHandler();
    }
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    
}
@end
@interface TestSessionDelegate_NoCollectingMetrics()
@property (nonatomic, copy) Completion completionHandler;
@end
@implementation TestSessionDelegate_NoCollectingMetrics
-(instancetype)initWithCompletionHandler:(Completion)completionHandler{
    self = [super init];
    if(self){
        _completionHandler = completionHandler;
    }
    return self;
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if(self.completionHandler){
        self.completionHandler();
    }
}
@end

@implementation  TestSessionDelegate_OnlyCollectingMetrics

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    
}

@end

@implementation TestSessionDelegate_None


@end

@implementation FTURLSessionCompleteTestDelegate
- (void)URLSession:(NSURLSession *)session didCreateTask:(NSURLSessionTask *)task{
    
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    self.URLSessionTaskDidCompleteWithErrorCalledCount += 1;
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    self.URLSessionDataTaskDidReceiveDataCalledCount += 1;
}
@end

@implementation FTURLSessionNoCompleteTestDelegate
- (void)URLSession:(NSURLSession *)session didCreateTask:(NSURLSessionTask *)task{
    
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    self.URLSessionDataTaskDidReceiveDataCalledCount += 1;
}
@end


@implementation FTURLSessionNoDidFinishCollectingMetrics

- (void)URLSession:(NSURLSession *)session didCreateTask:(NSURLSessionTask *)task{
    
}
@end
