//
//  FTDURLSessionDelegate.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/20.
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

#import "FTURLSessionInstrumentation.h"
#import "FTDURLSessionDelegate.h"

@implementation FTDURLSessionDelegate
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    if(FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor){
        [FTURLSessionInstrumentation.sharedInstance.interceptor taskReceivedData:dataTask data:data];
    }
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    if(FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor){
        [FTURLSessionInstrumentation.sharedInstance.interceptor taskMetricsCollected:task metrics:metrics custom:NO];
    }
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if(FTURLSessionInstrumentation.sharedInstance.shouldRUMInterceptor){
        [FTURLSessionInstrumentation.sharedInstance.interceptor taskCompleted:task error:error];
    }
}
@end
