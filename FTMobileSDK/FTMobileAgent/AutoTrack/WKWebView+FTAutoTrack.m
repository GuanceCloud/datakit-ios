//
//  WKWebView+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewHandler.h"
#import "FTSwizzler.h"
#import <objc/runtime.h>
#import "FTURLSessionInterceptorProtocol.h"
#import "FTGlobalManager.h"
@implementation WKWebView (FTAutoTrack)

-(WKNavigation *)dataflux_loadRequest:(NSURLRequest *)request{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        NSURLRequest *newrequest = [[FTGlobalManager sharedInstance].sessionInstrumentation.interceptor injectTraceHeader:request];
        [[FTWKWebViewHandler sharedInstance] addWebView:self request:request];
        return  [self dataflux_loadRequest:newrequest];
    }else{
        return [self dataflux_loadRequest:request];
    }
}

-(WKNavigation *)dataflux_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self dataflux_loadHTMLString:string baseURL:baseURL];
}

-(WKNavigation *)dataflux_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL{
    [[FTWKWebViewHandler sharedInstance] addScriptMessageHandlerWithWebView:self];
    return [self dataflux_loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}
-(WKNavigation *)dataflux_reload{
    if ([FTWKWebViewHandler sharedInstance].enableTrace) {
        __block BOOL trace = NO;
        __block NSURLRequest *newRequest = nil;
        [[FTWKWebViewHandler sharedInstance] reloadWebView:self completionHandler:^(NSURLRequest * _Nonnull request, BOOL needTrace) {
            if (needTrace && request) {
                trace = YES;
                newRequest = request;
            }
        }];
        return  trace?[self loadRequest:newRequest]:[self dataflux_reload];
    }else{
        return [self dataflux_reload];
    }
}

-(void)dataflux_dealloc{
    [[FTWKWebViewHandler sharedInstance] removeWebView:self];
    [self dataflux_dealloc];
}

@end

