//
//  NSURLSession+FTSwizzler.m
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


#import "NSURLSession+FTSwizzler.h"
#import "URLSessionAutoInstrumentation.h"
#import "FTURLSessionDelegate.h"

@implementation NSURLSession (FTSwizzler)
- (NSURLSessionDataTask *)ft_dataTaskWithURL:(NSURL *)url{
    
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        return nil;
    }else{
        return [self ft_dataTaskWithURL:url];
    }
}
- (NSURLSessionDataTask *)ft_dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        id <FTURLSessionDelegateProviding> delegate =(id <FTURLSessionDelegateProviding>)self.delegate;
        if (completionHandler != nil) {
            }
        return nil;
    }else{
        return [self ft_dataTaskWithURL:url completionHandler:completionHandler];
    }
}
- (NSURLSessionDataTask *)ft_dataTaskWithRequest:(NSURLRequest *)request{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        return nil;
    }else{
        return [self ft_dataTaskWithRequest:request];
    }
}
- (NSURLSessionDataTask *)ft_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(FTURLSessionDelegateProviding)]){
        return nil;
    }else{
        return [self ft_dataTaskWithRequest:request completionHandler:completionHandler];
    }
}
@end
