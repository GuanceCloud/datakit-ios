//
//  FTDURLSessionDelegate.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/20.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
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
