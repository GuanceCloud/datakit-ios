//
//  FTWKWebViewJavascriptBridge.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/1/5.
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

#import "FTWKWebViewJavascriptBridge.h"
#if !TARGET_OS_TV
#import "FTWebViewJavascriptLeakAvoider.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTSRWebTrackingProtocol.h"
#import "FTModuleManager.h"
#import "FTInternalConstants.h"
#import "FTSwizzle.h"
#import <objc/runtime.h>

NSString *const kAllowedHostsPlaceholder = @"__ALLOWED_HOSTS__";
NSString *const kCapabilitiesPlaceholder = @"__CAPABILITIES__";
NSString *const kPrivacyLevelPlaceholder = @"__PRIVACY_LEVEL__";
NSString *const kFTJsCodePrefix = @"/* FTWebViewJavascriptBridge */";
@implementation FTBindInfo

@end
// WKWebView message handlers are asynchronous. A reserved prompt supplies a
// synchronous read without caching an ID across native reset or TTL rotation.
static NSString *const FTVisitorIDPrompt = @"FTWebViewJavascriptBridge.getVisitorid";
static const void *FTVisitorIDDelegateKey = &FTVisitorIDDelegateKey;

@interface FTVisitorIDUIDelegate : NSObject <WKUIDelegate>
@property (nonatomic, weak) id<WKUIDelegate> delegate;
@property (nonatomic, weak) FTWKWebViewJavascriptBridge *bridge;
@end

@interface WKWebView (FTVisitorIDBridge)
- (void)ft_visitor_setUIDelegate:(id<WKUIDelegate>)delegate;
@end

@implementation WKWebView (FTVisitorIDBridge)
- (void)ft_visitor_setUIDelegate:(id<WKUIDelegate>)delegate {
    FTVisitorIDUIDelegate *proxy = objc_getAssociatedObject(self, FTVisitorIDDelegateKey);
    if (proxy && delegate != proxy) {
        proxy.delegate = delegate;
        delegate = proxy;
    }
    [self ft_visitor_setUIDelegate:delegate];
}
@end

@interface FTWKWebViewJavascriptBridge()
@property (nonatomic, weak, nullable) WKWebView *webView;
@property (nonatomic, strong) FTVisitorIDUIDelegate *visitorIDDelegate;
@property (nonatomic, copy) NSArray<NSString *> *visitorIDAllowedHosts;
- (BOOL)allowsVisitorIDForFrame:(WKFrameInfo *)frame;
@end

@implementation FTVisitorIDUIDelegate
- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [self.delegate respondsToSelector:selector];
}
- (id)forwardingTargetForSelector:(SEL)selector {
    return [self.delegate respondsToSelector:selector] ? self.delegate : [super forwardingTargetForSelector:selector];
}
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
   defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame
 completionHandler:(void (^)(NSString *))completionHandler {
    if ([prompt isEqualToString:FTVisitorIDPrompt]) {
        NSString *value = nil;
        @try {
            if ([self.bridge allowsVisitorIDForFrame:frame]) {
                id<FTWebViewVisitorIDProvider> provider = self.bridge.visitorIDProvider;
                value = [provider currentVisitorID];
            }
        } @catch (__unused NSException *exception) {
            // Returning nil lets the Browser SDK fall back to its own identifier.
        }
        completionHandler(value);
        return;
    }
    id<WKUIDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:_cmd]) {
        [delegate webView:webView runJavaScriptTextInputPanelWithPrompt:prompt defaultText:defaultText
        initiatedByFrame:frame completionHandler:completionHandler];
    } else {
        completionHandler(nil);
    }
}
@end
@implementation FTWKWebViewJavascriptBridge{
    long _uniqueId;
    FTWebViewJavascriptBridgeBase *_base;
}
+ (instancetype)bridgeForWebView:(WKWebView*)webView allowWebViewHostsString:(NSString *)hostsString{
    FTWKWebViewJavascriptBridge* bridge = [[self alloc] init];
    [bridge _setupInstance:webView allowWebViewHostsString:hostsString];
    return bridge;
}

- (void)callHandler:(NSString *)handlerName {
    [self callHandler:handlerName data:nil responseCallback:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data {
    [self callHandler:handlerName data:data responseCallback:nil];
}

- (void)callHandler:(NSString *)handlerName data:(id)data responseCallback:(WVJBResponseCallback)responseCallback {
    [_base sendData:data responseCallback:responseCallback handlerName:handlerName];
}

- (void)registerHandler:(NSString *)handlerName handler:(WVJBHandler)handler {
    _base.messageHandlers[handlerName] = [handler copy];
}

- (void)removeHandler:(NSString *)handlerName {
    [_base.messageHandlers removeObjectForKey:handlerName];
}
- (void)_setupInstance:(WKWebView*)webView allowWebViewHostsString:(NSString *)hostsString{
    _webView = webView;
    _base = [[FTWebViewJavascriptBridgeBase alloc] init];
    _base.delegate = self;
    [self removeScriptMessageHandler];
    [self addScriptMessageHandler];
    [self _injectJavascriptFile:hostsString];
    id hosts = [NSJSONSerialization JSONObjectWithData:[hostsString dataUsingEncoding:NSUTF8StringEncoding]
                                               options:NSJSONReadingFragmentsAllowed error:nil];
    if ([hosts isKindOfClass:NSString.class]) {
        hosts = [NSJSONSerialization JSONObjectWithData:[hosts dataUsingEncoding:NSUTF8StringEncoding]
                                               options:NSJSONReadingFragmentsAllowed error:nil];
    }
    // The existing bridge represents unrestricted hosts as JSON null.
    self.visitorIDAllowedHosts = hosts == NSNull.null ? nil : ([hosts isKindOfClass:NSArray.class] ? hosts : @[]);
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [WKWebView ft_swizzleMethod:@selector(setUIDelegate:)
                        withMethod:@selector(ft_visitor_setUIDelegate:) error:nil];
    });
    FTVisitorIDUIDelegate *proxy = [FTVisitorIDUIDelegate new];
    proxy.bridge = self;
    proxy.delegate = webView.UIDelegate;
    self.visitorIDDelegate = proxy;
    objc_setAssociatedObject(webView, FTVisitorIDDelegateKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    webView.UIDelegate = proxy;
}
- (BOOL)allowsVisitorIDForFrame:(WKFrameInfo *)frame {
    if (!frame.isMainFrame) return NO;
    if (!self.visitorIDAllowedHosts) return YES;
    NSString *host = frame.securityOrigin.host.lowercaseString;
    if (!host.length) return NO;
    for (id entry in self.visitorIDAllowedHosts) {
        if (![entry isKindOfClass:NSString.class] || ![entry length]) continue;
        NSString *allowed = [entry lowercaseString];
        if ([host isEqualToString:allowed] || [host hasSuffix:[@"." stringByAppendingString:allowed]]) return YES;
    }
    return NO;
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:FT_SCRIPT_MESSAGE_HANDLER_NAME]) {
        return;
    }
    NSString * body = (NSString * )message.body;
    if (body && [body isKindOfClass:[NSString class]]){
        [_base flushMessageQueue:body slotId:message.webView.hash];
    }
}
- (void)_injectJavascriptFile:(NSString *)allowWebViewHost {
    NSString *bridge_js = FTWebViewJavascriptBridge_js(allowWebViewHost);
    //injected the method when H5 starts to create the DOM tree
    WKUserScript * bridge_userScript = [[WKUserScript alloc]initWithSource:bridge_js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [_webView.configuration.userContentController addUserScript:bridge_userScript];
 
}
- (void) addScriptMessageHandler {
    [_webView.configuration.userContentController addScriptMessageHandler:[[FTWebViewJavascriptLeakAvoider alloc]initWithDelegate:self] name:FT_SCRIPT_MESSAGE_HANDLER_NAME];
}

- (void)removeScriptMessageHandler {
    FTVisitorIDUIDelegate *proxy = self.visitorIDDelegate;
    if (proxy) {
        objc_setAssociatedObject(_webView, FTVisitorIDDelegateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (_webView.UIDelegate == proxy) _webView.UIDelegate = proxy.delegate;
        proxy.bridge = nil;
        self.visitorIDDelegate = nil;
    }
    [_webView.configuration.userContentController removeScriptMessageHandlerForName:FT_SCRIPT_MESSAGE_HANDLER_NAME];
    WKUserContentController *controller = _webView.configuration.userContentController;
    NSArray *userScripts = controller.userScripts;
    if (userScripts.count>0) {
        NSArray<WKUserScript *> *others = [userScripts filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(WKUserScript *script, NSDictionary *bindings) {
                return ![script.source hasPrefix:kFTJsCodePrefix];
            }]];
        [controller removeAllUserScripts];
        for (WKUserScript *script in others) {
            [controller addUserScript:script];
        }
    }
}
- (void) _evaluateJavascript:(NSString*)javascriptCommand {
    [_webView evaluateJavaScript:javascriptCommand completionHandler:nil];
}

NSString * FTWebViewJavascriptBridge_js(NSString *hostsString) {
    NSString *allowedHosts = hostsString?:@"";
    id<FTSRWebTrackingProtocol> sessionReplay = [[FTModuleManager sharedInstance] getRegisterService:NSProtocolFromString(@"FTSRWebTrackingProtocol")];
      NSString *capabilities = sessionReplay ? @"\\\"records\\\"" : @"";
      NSString *privacyLevel = sessionReplay ? [sessionReplay getSessionReplayPrivacyLevel] : @"mask";
#define __WVJB_js_func__(x) #x
    //FTWebViewJavascriptBridge
    // BEGIN preprocessorJSCode
    static NSString * preprocessorJSCode = @__WVJB_js_func__(
                                                             ;(function(window) {
        /* FTWebViewJavascriptBridge */
        window.FTWebViewJavascriptBridge = {
        registerHandler: ftRegisterHandler,
        callHandler: ftCallHandler,
        sendEvent: ftSendEvent,
        getAllowedWebViewHosts: getAllowedWebViewHosts,
        getVisitorid: getVisitorid,
        getCapabilities: getCapabilities,
        getPrivacyLevel: getPrivacyLevel,
        _handleMessageFromObjC: _ftHandleMessageFromObjC
        };
        
        var ftSendMessageQueue = [];
        var ftMessageHandlers = {};
        var ftResponseCallbacks = {};
        var uniqueId = 1;
        
        function getVisitorid(){
            try {
                var value = window.prompt('FTWebViewJavascriptBridge.getVisitorid', "");
                return typeof value === 'string' && value.length > 0 ? value : null;
            } catch (error) {
                return null;
            }
        }
        function getAllowedWebViewHosts(){
            return __ALLOWED_HOSTS__;
        }
                                                                 
        function ftRegisterHandler(handlerName, handler) {
            ftMessageHandlers[handlerName] = handler;
        }
        function ftSendEvent(data, responseCallback){
            ftCallHandler('sendEvent', data, responseCallback);
        }
                                                                 
        function ftCallHandler(handlerName, data, responseCallback) {
            if (arguments.length === 2 && typeof data == 'function') {
                responseCallback = data;
                data = null;
            }
            _ftDoSend({ handlerName:handlerName, data:data }, responseCallback);
        }
        function _ftDoSend(message, responseCallback) {
            if (responseCallback) {
                var callbackId = 'cb_'+(uniqueId++)+'_'+new Date().getTime();
                ftResponseCallbacks[callbackId] = responseCallback;
                message['callbackId'] = callbackId;
            }
            ftSendMessageQueue.push(message);
            window.webkit.messageHandlers.ftMobileSdk.postMessage(JSON.stringify(ftSendMessageQueue));
            ftSendMessageQueue = [];
        }
        
        function _ftDispatchMessageFromObjC(messageJSON) {
            _doDispatchMessageFromObjC();
            
            function _doDispatchMessageFromObjC() {
                var message = JSON.parse(messageJSON);
                var messageHandler;
                var responseCallback;
                
                if (message.responseId) {
                    responseCallback = ftResponseCallbacks[message.responseId];
                    if (!responseCallback) {
                       
                        return;
                    }
                    
                    responseCallback(message.responseData);
                    delete ftResponseCallbacks[message.responseId];
                } else {
                    if (message.callbackId) {
                        var callbackResponseId = message.callbackId;
                        responseCallback = function(responseData) {
                            _doSend({ handlerName:message.handlerName, responseId:callbackResponseId, responseData:responseData });
                        };
                    }
                    var handler = ftMessageHandlers[message.handlerName];
                    if (!handler) {
                        console.log("WebViewJavascriptBridge: WARNING: no handler for message from ObjC:", message);
                    } else {
                        handler(message.data, responseCallback);
                    }
                }
            }
        }
        function _ftHandleMessageFromObjC(messageJSON) {
            _ftDispatchMessageFromObjC(messageJSON);
        }
        
        function getCapabilities() {
            return "[__CAPABILITIES__]";
        }
        function  getPrivacyLevel() {
            return "__PRIVACY_LEVEL__";
        }
    })(window);
                                                             ); // END preprocessorJSCode
    
#undef __WVJB_js_func__
    NSString *jsCode = [NSString stringWithFormat:@"%@\n%@",kFTJsCodePrefix,[preprocessorJSCode stringByReplacingOccurrencesOfString:kAllowedHostsPlaceholder  withString:allowedHosts]];
    jsCode = [jsCode stringByReplacingOccurrencesOfString:kCapabilitiesPlaceholder
                                               withString:capabilities];
    jsCode = [jsCode stringByReplacingOccurrencesOfString:kPrivacyLevelPlaceholder
                                               withString:privacyLevel];
  return jsCode;
};


@end
#endif
