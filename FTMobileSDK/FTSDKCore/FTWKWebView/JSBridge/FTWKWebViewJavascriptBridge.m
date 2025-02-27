//
//  FTWKWebViewJavascriptBridge.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/5.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTWKWebViewJavascriptBridge.h"
#if !TARGET_OS_TV
#import "FTWebViewJavascriptLeakAvoider.h"
#import "FTConstants.h"
@interface FTWKWebViewJavascriptBridge()
@property (nonatomic, weak) WKWebView *webView;
@end
@implementation FTWKWebViewJavascriptBridge{
    long _uniqueId;
    FTWebViewJavascriptBridgeBase *_base;
}
+ (instancetype)bridgeForWebView:(WKWebView*)webView{
    FTWKWebViewJavascriptBridge* bridge = [[self alloc] init];
    [bridge _setupInstance:webView];
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
- (void)_setupInstance:(WKWebView*)webView{
    _webView = webView;
    _base = [[FTWebViewJavascriptBridgeBase alloc] init];
    _base.delegate = self;
    [self removeScriptMessageHandler];
    [self addScriptMessageHandler];
    [self _injectJavascriptFile];
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:FT_SCRIPT_MESSAGE_HANDLER_NAME]) {
        return;
    }
    NSString * body = (NSString * )message.body;
    if (body && [body isKindOfClass:[NSString class]]){
        [_base flushMessageQueue:body];
    }
}
- (void)_injectJavascriptFile {
    NSString *bridge_js = FTWebViewJavascriptBridge_js();
    //injected the method when H5 starts to create the DOM tree
    WKUserScript * bridge_userScript = [[WKUserScript alloc]initWithSource:bridge_js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [_webView.configuration.userContentController addUserScript:bridge_userScript];
 
}
- (void) addScriptMessageHandler {
    [_webView.configuration.userContentController addScriptMessageHandler:[[FTWebViewJavascriptLeakAvoider alloc]initWithDelegate:self] name:FT_SCRIPT_MESSAGE_HANDLER_NAME];
}

- (void)removeScriptMessageHandler {
    [_webView.configuration.userContentController removeScriptMessageHandlerForName:FT_SCRIPT_MESSAGE_HANDLER_NAME];
}

- (void) _evaluateJavascript:(NSString*)javascriptCommand {
    [_webView evaluateJavaScript:javascriptCommand completionHandler:nil];
}

-(void)dealloc{
    [self removeScriptMessageHandler];
}

NSString * FTWebViewJavascriptBridge_js(void) {
#define __WVJB_js_func__(x) #x
    //FTWebViewJavascriptBridge
    // BEGIN preprocessorJSCode
    static NSString * preprocessorJSCode = @__WVJB_js_func__(
                                                             ;(function(window) {
               
        window.FTWebViewJavascriptBridge = {
        registerHandler: ftRegisterHandler,
        callHandler: ftCallHandler,
        sendEvent: ftSendEvent,
        _handleMessageFromObjC: _ftHandleMessageFromObjC
        };
        
        var ftSendMessageQueue = [];
        var ftMessageHandlers = {};
        var ftResponseCallbacks = {};
        var uniqueId = 1;
        
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
    })(window);
                                                             ); // END preprocessorJSCode
    
#undef __WVJB_js_func__
    return preprocessorJSCode;
};


@end
#endif
