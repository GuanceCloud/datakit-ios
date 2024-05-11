//
//  WKWebView+FTAutoTrack.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/7/28.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKWebView (FTAutoTrack)
-(WKNavigation *)ft_loadRequest:(NSURLRequest *)request;
-(WKNavigation *)ft_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
-(WKNavigation *)ft_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL;
-(WKNavigation *)ft_reload;
-(void)ft_dealloc;
@end

NS_ASSUME_NONNULL_END
