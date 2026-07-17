//
//  TestSessionDelegate.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/1/24.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import "TestSessionDelegate.h"
@interface TestSessionDelegate()
@property (nonatomic, copy) Completion completionHandler;
@end
@implementation TestSessionDelegate
-(instancetype)initWithCompletionHandler:(Completion)completionHandler{
    self = [super init];
    if(self){
        _completionHandler = [completionHandler copy];
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
        _completionHandler = [completionHandler copy];
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
