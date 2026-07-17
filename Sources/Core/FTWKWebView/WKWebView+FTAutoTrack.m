//
//  WKWebView+FTAutoTrack.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/7/28.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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

#import <TargetConditionals.h>
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewHandler+Private.h"
#import "FTSwizzler.h"
#import <objc/runtime.h>

static char *kLinkRumKeysInfo = "kLinkRumKeysInfo";

@implementation WKWebView (FTAutoTrack)
-(NSDictionary *)ft_linkRumKeysInfo{
    return objc_getAssociatedObject(self, &kLinkRumKeysInfo);
}
-(void)setFt_linkRumKeysInfo:(NSDictionary *)ft_linkRumKeysInfo{
    objc_setAssociatedObject(self, &kLinkRumKeysInfo, ft_linkRumKeysInfo, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
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
