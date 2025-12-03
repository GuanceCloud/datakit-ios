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
#import "FTWKWebViewHandler+SessionReplay.h"

@interface FTWKWebViewHandler ()
@property (nonatomic, weak) id<FTWKWebViewRumDelegate> rumTrackDelegate;
@property (nonatomic, strong) NSMapTable *webViewBridge;
@property (nonatomic, copy) NSString *allowWebViewHostsString;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, assign) BOOL enableTraceWebView;
@end

@implementation FTWKWebViewHandler
@synthesize hiddenSlotIds = _hiddenSlotIds;
@synthesize enableLinkRUMKeys = _enableLinkRUMKeys;
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
        FTInnerLogInfo(@"[WebView] webView(%lld) start bridge",(uint64_t)webView.hash);
        FTWKWebViewJavascriptBridge *bridge = [FTWKWebViewJavascriptBridge bridgeForWebView:webView allowWebViewHostsString:hostsString];
        FTBindInfo *bindInfo = [[FTBindInfo alloc] init];
        bindInfo.container = webView;
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
                    if (!info.viewId) {
                        info.viewId = self.rumTrackDelegate ? [self.rumTrackDelegate getLastHasReplayViewID] : nil;
                    }
                    if (!info.viewReferrer) {
                        info.viewReferrer = self.rumTrackDelegate ? [self.rumTrackDelegate getLastViewName] : nil;
                    }
                    if (info.viewId) {
                        NSArray *linkRUMKeys = self.enableLinkRUMKeys;
                        if (linkRUMKeys.count>0 && (info.container.ft_linkRumKeysInfo == nil ||  info.container.ft_linkRumKeysInfo.count == 0)) {
                            NSMutableDictionary *infoDict = [[NSMutableDictionary alloc]init];
                            NSEnumerator *en = [linkRUMKeys objectEnumerator];
                            NSString *key;
                            while ((key = en.nextObject) != nil) {
                                [infoDict setValue:fields[key] forKey:key];
                            }
                            if (infoDict.count>0) {
                                info.container.ft_linkRumKeysInfo = [infoDict copy];
                                [self bindInfo:info.container.ft_linkRumKeysInfo viewId:info.viewId];
                            }else{
                                FTInnerLogDebug(@"[WebView] webView(%lld:%@) bindInfo fail.",slotID,tags[FT_KEY_VIEW_ID]);
                            }
                        }
                        [tags setValue:@{@"source":@"ios",@"view_id":info.viewId} forKey:@"container"];
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
            [dict setValue:info.container.ft_linkRumKeysInfo forKey:FT_LINK_RUM_KEYS];
            [[FTModuleManager sharedInstance] postMessage:FTMessageKeyWebViewSR message:dict];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"%@ error: %@", self, exception);
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
#pragma mark ========= FTWKWebViewHandler+SessionReplay ========
-(void)setEnableLinkRUMKeys:(NSArray *)enableLinkRUMKeys{
    [self.lock lock];
    _enableLinkRUMKeys = [enableLinkRUMKeys copy];
    [self.lock unlock];
}
-(NSArray *)enableLinkRUMKeys{
    id list = nil;
    [self.lock lock];
    list = [_enableLinkRUMKeys copy];
    [self.lock unlock];
    return list;
}
-(void)setHiddenSlotIds:(NSSet<NSNumber *> *)hiddenSlotIds{
    [self.lock lock];
    _hiddenSlotIds = hiddenSlotIds;
    [self.lock unlock];
}
-(NSSet<NSNumber *> *)hiddenSlotIds{
    NSSet<NSNumber *> *slotIds = nil;
    [self.lock lock];
    slotIds = [_hiddenSlotIds copy];
    [self.lock unlock];
    return slotIds;
}
- (void)takeSubsequentFullSnapshot{
    NSArray *allKeys = [self.webViewBridge keyEnumerator].allObjects;
    for (WKWebView *key in allKeys) {
        BOOL isHidden = [self.hiddenSlotIds containsObject:@(key.hash)];
        id value = [self.webViewBridge objectForKey:key];
        if (!isHidden && key && value) {
            [FTThreadDispatchManager performBlockDispatchMainAsync:^{
                [key evaluateJavaScript:@"DATAFLUX_RUM.takeSubsequentFullSnapshot()" completionHandler:nil];
            }];
        }
    }
}
- (void)bindInfo:(NSDictionary *)info viewId:(NSString *)viewId{
    if(self.rumTrackDelegate){
        [self.rumTrackDelegate bindSRInfo:info containerViewID:viewId];
    }
}
@end

#endif
