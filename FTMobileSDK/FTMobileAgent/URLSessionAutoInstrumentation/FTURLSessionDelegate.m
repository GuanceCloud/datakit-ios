//
//  FTURLSessionDelegate.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/9/13.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#import "FTURLSessionDelegate.h"
#import "FTURLSessionAutoInstrumentation.h"
#import "FTURLSessionInterceptorProtocol.h"

@interface FTURLSessionDelegate()
@property (nonatomic, strong,readwrite) FTURLSessionAutoInstrumentation *instrumentation;
@end
@implementation FTURLSessionDelegate
@synthesize ftURLSessionDelegate;
-(FTURLSessionDelegate *)ftURLSessionDelegate{
    return self;
}
- (FTURLSessionAutoInstrumentation *)instrumentation{
    return [FTURLSessionAutoInstrumentation sharedInstance];
}
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.instrumentation.interceptor taskReceivedData:dataTask data:data];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    [self.instrumentation.interceptor taskMetricsCollected:task metrics:metrics];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [self.instrumentation.interceptor taskCompleted:task error:error];
}

@end
