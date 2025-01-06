//
//  NSURLSessionTask+FTSwizzler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/1/2.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "NSURLSessionTask+FTSwizzler.h"
#import "FTURLSessionInstrumentation.h"
#import <objc/runtime.h>

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
- (void)ft_resume{
    id<FTURLSessionInterceptorProtocol> traceInterceptor = [[FTURLSessionInstrumentation sharedInstance] traceInterceptor:[self ft_delegate]];
    id<FTURLSessionInterceptorProtocol> rumInterceptor = [[FTURLSessionInstrumentation sharedInstance] rumInterceptor:[self ft_delegate]];
    [traceInterceptor traceInterceptTask:self];
    [rumInterceptor interceptTask:self];
    
    [self ft_resume];
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
@end
