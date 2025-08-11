//
//  WKWebView+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//
#import <TargetConditionals.h>
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewHandler+Private.h"
#import "FTSwizzler.h"
#import <objc/runtime.h>
@implementation WKWebView (FTAutoTrack)

-(WKNavigation *)ft_loadRequest:(NSURLRequest *)request{
    [[FTWKWebViewHandler sharedInstance] innerEnableWebView:self];
    return [self ft_loadRequest:request];
}

-(WKNavigation *)ft_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL{
    [[FTWKWebViewHandler sharedInstance] innerEnableWebView:self];
    return [self ft_loadHTMLString:string baseURL:baseURL];
}

-(WKNavigation *)ft_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL{
    [[FTWKWebViewHandler sharedInstance] innerEnableWebView:self];
    return [self ft_loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}
-(void)ft_dealloc{
    [[FTWKWebViewHandler sharedInstance] disableWebView:self];
    [self ft_dealloc];
}
@end
#endif
