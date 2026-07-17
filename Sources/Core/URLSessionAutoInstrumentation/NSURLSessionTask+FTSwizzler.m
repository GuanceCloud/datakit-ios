//
//  NSURLSessionTask+FTSwizzler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/1/2.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

#import "NSURLSessionTask+FTSwizzler.h"
#import "FTURLSessionInstrumentation.h"
#import <objc/runtime.h>
#import "FTInnerLog.h"
static char *hasCompletionKey = "hasCompletionKey";
@implementation NSURLSessionTask (FTSwizzler)

-(void)setFt_hasCompletion:(BOOL)hasCompletion{
    objc_setAssociatedObject(self, &hasCompletionKey, @(hasCompletion), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(BOOL)ft_hasCompletion{
    NSNumber *hasCompletion = objc_getAssociatedObject(self, &hasCompletionKey);
    if(hasCompletion!=nil){
        return [hasCompletion boolValue];
    }
    return NO;
}
- (id<NSURLSessionDelegate>)ft_delegate{
    if (@available(iOS 15.0,tvOS 15.0,macOS 12.0, *)) {
        if(self.delegate){
            return self.delegate;
        }
    }
    NSURLSession *session = [self valueForKey:@"session"];
    if(session){
        return session.delegate;
    }
    return nil;
}
+ (NSArray<Class> *)unsupportedTaskClasses {
    static NSArray<Class> *classes = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *classNames = @[
            @"AVAssetDownloadTask",
            @"NSURLSessionAVAssetDownloadTask",
            @"AVAggregateAssetDownloadTask",
            @"NSURLSessionAVAggregateAssetDownloadTask"
        ];
        
        NSMutableArray<Class> *tmpClasses = [NSMutableArray array];
        for (NSString *className in classNames) {
            Class cls = NSClassFromString(className);
            if (cls) {
                [tmpClasses addObject:cls];
            }
        }
        classes = [tmpClasses copy];
    });
    return classes;
}
- (BOOL)ft_isSupportedForInstrumentation {
    for (Class cls in [NSURLSessionTask unsupportedTaskClasses]) {
        if ([self isKindOfClass:cls]) {
            return NO;
        }
    }
    return YES;
}
@end
