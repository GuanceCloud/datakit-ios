//
//  FTWKWebViewHandler.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/9/16.
//  Copyright © 2020 hll. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "FTWKWebViewHandler.h"
#import "FTWKWebViewHandler+Private.h"
#if !TARGET_OS_TV
#import "WKWebView+FTAutoTrack.h"
#import "FTWKWebViewJavascriptBridge.h"
#import "FTSwizzler.h"
#import "FTSwizzle.h"
#import "FTLog+Private.h"
#import "FTReadWriteHelper.h"
#import <os/lock.h>
#import "FTConstants.h"
#import "FTModuleManager.h"
#import "FTJSONUtil.h"
#import "FTWeakMapTable.h"
#import "FTThreadDispatchManager.h"

@interface FTWKWebViewHandler ()
@property (nonatomic, weak) id<FTWKWebViewRumDelegate> rumTrackDelegate;
@property (nonatomic, strong) NSMapTable *webViewBridge;
@property (nonatomic, copy) NSString *allowWebViewHostsString;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL enableTraceWebView;
@end
@implementation FTWKWebViewHandler
@synthesize whiteLists = _whiteLists;
static FTWKWebViewHandler *sharedInstance = nil;
static NSObject *sharedInstanceLock;
+ (void)initialize{
    if (self == [FTWKWebViewHandler class]) {
        sharedInstanceLock = [[NSObject alloc] init];
    }
}
+ (instancetype)sharedInstance {
    @synchronized(sharedInstanceLock) {
        if (!sharedInstance) {
            sharedInstance = [[self alloc] init];
        }
        return sharedInstance;
    }
}
-(instancetype)init{
    self = [super init];
    if (self) {
        self.webViewBridge = [NSMapTable weakToStrongObjectsMapTable];
        self.lock = [NSLock new];
        self.enableTraceWebView = NO;
    }
    return self;
}
- (void)startWithEnableTraceWebView:(BOOL)enable allowWebViewHost:(NSArray *)hosts rumDelegate:(id<FTWKWebViewRumDelegate>)delegate{
    _enableTraceWebView = enable;
    if (enable) {
        [self setWKWebViewTrace];
    }
    self.allowWebViewHostsString = [self transHostsArrayToString:hosts];
    self.rumTrackDelegate = delegate;
}
- (void)setWKWebViewTrace{
    static dispatch_once_t onceTokenWebView;
    dispatch_once(&onceTokenWebView, ^{
        NSError *error = NULL;
        [WKWebView ft_swizzleMethod:@selector(loadRequest:)
                         withMethod:@selector(ft_loadRequest:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadHTMLString:baseURL:)
                         withMethod:@selector(ft_loadHTMLString:baseURL:)
                              error:&error];
        [WKWebView ft_swizzleMethod:@selector(loadFileURL:allowingReadAccessToURL:)
                         withMethod:@selector(ft_loadFileURL:allowingReadAccessToURL:)
                              error:&error];
        SEL deallocMethod =  NSSelectorFromString(@"dealloc");
        [WKWebView ft_swizzleMethod:deallocMethod
                         withMethod:@selector(ft_dealloc)
                              error:&error];
    });
}
-(void)setWhiteLists:(NSArray *)whiteLists{
    [self.lock lock];
    _whiteLists = [whiteLists copy];
    self.linkRumInfos = [[FTWeakMapTable alloc]init];
    [self.lock unlock];
}
-(NSArray *)whiteLists{
    id list = nil;
    [self.lock lock];
    list = [_whiteLists copy];
    [self.lock unlock];
    return list;
}
#pragma mark request
- (void)addWebView:(WKWebView *)webView bridge:(id)bridge{
    [self.lock lock];
    [self.webViewBridge setObject:bridge forKey:webView];
    [self.lock unlock];
}
- (id)getWebViewBridge:(WKWebView *)webView{
    id bridge = nil;
    [self.lock lock];
    bridge = [self.webViewBridge objectForKey:webView];
    [self.lock unlock];
    return bridge;
}
- (void)removeWebViewBridge:(WKWebView *)webView{
    [self.lock lock];
    [self.webViewBridge removeObjectForKey:webView];
    [self.lock unlock];
}
- (void)removeAllWebViewBridges{
    [self.lock lock];
    NSArray *allBridges = [self.webViewBridge.objectEnumerator allObjects];
    [self.lock unlock];
    for (FTWKWebViewJavascriptBridge *bridge in allBridges) {
        [bridge removeScriptMessageHandler];
    }
    [self.lock lock];
    [self.webViewBridge removeAllObjects];
    [self.lock unlock];
}
- (NSString *)transHostsArrayToString:(NSArray *)hosts{
    @try {
        if(hosts && hosts.count>0){
            NSArray *hostsCopy = [hosts copy];
            NSMutableArray<NSString *> *quotedHosts = [[NSMutableArray alloc] initWithCapacity:hostsCopy.count];
            [hostsCopy enumerateObjectsUsingBlock:^(NSString * _Nonnull host, NSUInteger idx, BOOL * _Nonnull stop) {
                [quotedHosts addObject:[NSString stringWithFormat:@"\\\"%@\\\"", host]];
            }];
            return  [NSString stringWithFormat:@"\"[%@]\"",[quotedHosts componentsJoinedByString:@","]];
        }else{
            return @"null";
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
    return @"null";
}
- (void)innerEnableWebView:(WKWebView *)webView{
    if (self.enableTraceWebView) {
        [self _enableWebView:webView allowedWebViewHostsString:self.allowWebViewHostsString];
    }
}
- (void)enableWebView:(WKWebView *)webView{
    [self _enableWebView:webView allowedWebViewHostsString:self.allowWebViewHostsString];
}
- (void)enableWebView:(WKWebView *)webView allowWebViewHost:(NSArray *)hosts{
    NSString *allowedHosts = [self transHostsArrayToString:hosts];
    [self _enableWebView:webView allowedWebViewHostsString:allowedHosts];
}
- (void)_enableWebView:(WKWebView *)webView allowedWebViewHostsString:(NSString *)hostsString{
    @try {
        if ([self getWebViewBridge:webView]) {
            FTInnerLogDebug(@"WebView(%lld) already add JSBridge.",(uint64_t)webView.hash);
            return;
        }
        FTInnerLogInfo(@"[WebView] webView(%lld) start bridge",(uint64_t)webView.hash);
        FTWKWebViewJavascriptBridge *bridge = [FTWKWebViewJavascriptBridge bridgeForWebView:webView allowWebViewHostsString:hostsString];
        FTBindInfo *bindInfo = [[FTBindInfo alloc] init];
#if TARGET_OS_IOS
        bindInfo.container = [self findViewControllerForWebView:webView];
#endif
        __weak typeof(self) weakSelf = self;
        [bridge registerHandler:@"sendEvent" handler:^(id data, int64_t slotId,WVJBResponseCallback responseCallback) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.rumTrackDelegate) return;
            [strongSelf dealReceiveScriptMessage:data slotId:slotId info:bindInfo];
        }];
        [self addWebView:webView bridge:bridge];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
#if TARGET_OS_IOS
- (nullable UIViewController *)findViewControllerForWebView:(nonnull WKWebView *)webView {
    UIView *currentView = webView;
    while (currentView) {
        UIResponder *nextResponder = currentView.nextResponder;
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)nextResponder;
        }
        currentView = currentView.superview;
    }
    return nil;
}
#endif
- (void)dealReceiveScriptMessage:(id )message slotId:(int64_t)slotID info:(FTBindInfo *)info{
    @try {
        NSDictionary *messageDic = [message isKindOfClass:NSDictionary.class]?message:[FTJSONUtil dictionaryWithJsonString:message];
        
        if (![messageDic isKindOfClass:[NSDictionary class]]) {
            FTInnerLogError(@"Message body is formatted failure from JS SDK");
            return;
        }
        NSString *name = messageDic[@"name"];
        if ([name isEqualToString:@"rum"]) {
            NSDictionary *data = messageDic[@"data"];
            NSString *measurement = data[FT_MEASUREMENT];
            NSMutableDictionary *tags = [data[FT_TAGS] mutableCopy];
            NSString *version = [tags valueForKey:FT_SDK_VERSION];
            if(version&&version.length>0){
                [tags setValue:@{@"web":version} forKey:FT_SDK_PKG_INFO];
            }
            NSDictionary *fields = data[FT_FIELDS];
            long long time = [data[@"time"] longLongValue];
            long long fixTime = time * 1000000;
            // Web time data is in milliseconds, native needs nanoseconds, need to convert units
            // Check if overflow
            if (time == fixTime/1000000) {
                time = fixTime;
            }
            if (measurement && fields.count>0) {
                if ([measurement isEqualToString:FT_RUM_SOURCE_VIEW]) {
                    NSArray *whiteLists = self.whiteLists;
                    if (whiteLists.count>0 && (info.bindInfo == nil ||  info.bindInfo.count == 0)) {
                        NSMutableDictionary *infoDict = [[NSMutableDictionary alloc]init];
                        NSEnumerator *en = [whiteLists objectEnumerator];
                        NSString *key;
                        while ((key = en.nextObject) != nil) {
                            [infoDict setValue:fields[key] forKey:key];
                        }
                        info.bindInfo = [infoDict copy];
                        [self.linkRumInfos setObject:info.bindInfo forKey:info.container];
                    }
                    if (!info.viewId) {
                        info.viewId = self.rumTrackDelegate ? [self.rumTrackDelegate getLastHasReplayViewIDWithSRBindInfo:info.bindInfo] : nil;
                    }
                    if (info.viewId) {
                        [tags setValue:@{@"source":@"ios",@"view_id":info.viewId} forKey:@"container"];
                    }
                    if (!info.viewReferrer) {
                        info.viewReferrer = self.rumTrackDelegate ? [self.rumTrackDelegate getLastViewName] : nil;
                    }
                    if (tags[FT_KEY_VIEW_REFERRER] == nil) {
                        [tags setValue:info.viewReferrer forKey:FT_KEY_VIEW_REFERRER];
                    }
                }else if ([measurement isEqualToString:FT_RUM_SOURCE_ERROR]){
                    [[FTModuleManager sharedInstance] postMessage:FTMessageKeyRumError message:@{
                        @"error_date":[NSDate date],
                        @"error_crash":@(NO)
                    } sync:NO];
                }
                [self.rumTrackDelegate dealRUMWebViewData:measurement tags:tags fields:fields tm:time];
            }
        }else if ([name isEqualToString:@"session_replay"]){
            NSMutableDictionary *dict = [messageDic mutableCopy];
            [dict setValue:[NSString stringWithFormat:@"%lld",slotID] forKey:@"slotId"];
            [dict setValue:info.bindInfo forKey:@"bindInfo"];
            [[FTModuleManager sharedInstance] postMessage:FTMessageKeyWebViewSR message:dict];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
    }
}
- (void)takeSubsequentFullSnapshot{
    NSArray *allKeys = [self.webViewBridge keyEnumerator].allObjects; //
    for (WKWebView *key in allKeys) {
        id value = [self.webViewBridge objectForKey:key]; 
        if (key && value) {
            [FTThreadDispatchManager performBlockDispatchMainAsync:^{
                [key evaluateJavaScript:@"DATAFLUX_RUM.takeSubsequentFullSnapshot()" completionHandler:nil];
            }];
        }
    }
}
- (void)disableWebView:(WKWebView *)webView{
    @try {
        FTWKWebViewJavascriptBridge *bridge = [self getWebViewBridge:webView];
        [self removeWebViewBridge:webView];
        [bridge removeScriptMessageHandler];
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"exception: %@",exception);
    }
}
+ (void)shutDown{
    @synchronized(sharedInstanceLock) {
        sharedInstance = nil;
    }
}
@end

#endif
