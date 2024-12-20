//
//  WKWebView+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//
#import <TargetConditionals.h>
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewHandler.h"
#import "FTSwizzler.h"
#import <objc/runtime.h>
#import "FTURLSessionInterceptorProtocol.h"
@implementation WKWebView (FTAutoTrack)

-(WKNavigation *)ft_loadRequest:(NSURLRequest *)request{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        NSURLRequest *newrequest = [[FTWKWebViewHandler sharedInstance].interceptor interceptRequest:request];
        [[FTWKWebViewHandler sharedInstance] addWebView:self request:request];
        return  [self ft_loadRequest:newrequest];
    }else{
        return [self ft_loadRequest:request];
    }
}

-(WKNavigation *)ft_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self ft_loadHTMLString:string baseURL:baseURL];
}

-(WKNavigation *)ft_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self ft_loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}
-(WKNavigation *)ft_reload{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        __block BOOL trace = NO;
        __block NSURLRequest *newRequest = nil;
        [[FTWKWebViewHandler sharedInstance] reloadWebView:self completionHandler:^(NSURLRequest * _Nonnull request, BOOL needTrace) {
            if (needTrace && request) {
                trace = YES;
                newRequest = request;
            }
        }];
        return  trace?[self loadRequest:newRequest]:[self ft_reload];
    }else{
        return [self ft_reload];
    }
}

-(void)ft_dealloc{
    [[FTWKWebViewHandler sharedInstance] removeWebView:self];
    [self ft_dealloc];
}

@end
#endif
