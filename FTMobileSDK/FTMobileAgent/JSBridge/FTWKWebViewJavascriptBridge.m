//
//  FTWKWebViewJavascriptBridge.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/5.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTWKWebViewJavascriptBridge.h"
#import "FTWebViewJavascriptLeakAvoider.h"

@interface FTWKWebViewJavascriptBridge()<FTWebViewJavascriptBridgeBaseDelegate>
@property (nonatomic, strong) NSMutableArray *handleEvent;
@end
@implementation FTWKWebViewJavascriptBridge{
    WKWebView* _webView;
    long _uniqueId;
    FTWebViewJavascriptBridgeBase *_base;
}
+ (instancetype)bridgeForWebView:(WKWebView*)webView{
    FTWKWebViewJavascriptBridge* bridge = [[self alloc] init];
    [bridge _setupInstance:webView];
    return bridge;
}

- (void)_setupInstance:(WKWebView*)webView{
    _webView = webView;
    _base = [[FTWebViewJavascriptBridgeBase alloc] init];
    _base.delegate = self;
    [self removeScriptMessageHandler];
    [self addScriptMessageHandler];
    [self _injectJavascriptFile];
}
- (void)addScriptMessageHandler{
    [_webView.configuration.userContentController addScriptMessageHandler:[[FTWebViewJavascriptLeakAvoider alloc]initWithDelegate:self] name:@"ftMobileSdk"];
}
- (void)removeScriptMessageHandler {
    [_webView.configuration.userContentController removeScriptMessageHandlerForName:@"ftMobileSdk"];
}
- (void)_injectJavascriptFile{
    NSString *bridge_js = WebViewJavascriptBridge_js();
    //injected the method when H5 starts to create the DOM tree
    WKUserScript * bridge_userScript = [[WKUserScript alloc]initWithSource:bridge_js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [_webView.configuration.userContentController addUserScript:bridge_userScript];
}
- (void)registerHandler:(NSString *)handlerName handler:(WVJBHandler)handler {
    _base.messageHandlers[handlerName] = [handler copy];
}
- (void)removeHandler:( NSString* )handlerName{
    [_base.messageHandlers removeObjectForKey:handlerName];
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
  
    if (![message.name isEqualToString:@"ftMobileSdk"]){
        return;
    }

    NSString * body = (NSString * )message.body;
    if (body && [body isKindOfClass:[NSString class]]) {
        NSMutableString *mstr = [NSMutableString stringWithString:body];
        [_base flushMessageQueue:mstr];
    }
}

- (NSString *)_evaluateJavascript:(nonnull NSString *)javascriptCommand {
    [_webView evaluateJavaScript:javascriptCommand completionHandler:nil];
    return NULL;
}

-(void)dealloc{
    [self removeScriptMessageHandler];
}
NSString * WebViewJavascriptBridge_js() {
#define __WVJB_js_func__(x) #x
    
    // BEGIN preprocessorJSCode
    static NSString * preprocessorJSCode = @__WVJB_js_func__(
                                                             ;(function(window) {
               
        window.WebViewJavascriptBridge = {
        registerHandler: registerHandler,
        callHandler: callHandler,
        _handleMessageFromObjC: _handleMessageFromObjC
        };
        
        var sendMessageQueue = [];
        var messageHandlers = {};
        var responseCallbacks = {};
        var uniqueId = 1;
        
        function registerHandler(handlerName, handler) {
            messageHandlers[handlerName] = handler;
        }
        
        function callHandler(handlerName, data, responseCallback) {
            if (arguments.length === 2 && typeof data == 'function') {
                responseCallback = data;
                data = null;
            }
            _doSend({ handlerName:handlerName, data:data }, responseCallback);
        }
        function _doSend(message, responseCallback) {
            if (responseCallback) {
                var callbackId = 'cb_'+(uniqueId++)+'_'+new Date().getTime();
                responseCallbacks[callbackId] = responseCallback;
                message['callbackId'] = callbackId;
            }
            sendMessageQueue.push(message);
            window.webkit.messageHandlers.ftMobileSdk.postMessage('__bridge__'+ JSON.stringify(sendMessageQueue));
            sendMessageQueue = [];
        }
        
        function _dispatchMessageFromObjC(messageJSON) {
            _doDispatchMessageFromObjC();
            
            function _doDispatchMessageFromObjC() {
                var message = JSON.parse(messageJSON);
                var messageHandler;
                var responseCallback;
                
                if (message.responseId) {
                    responseCallback = responseCallbacks[message.responseId];
                    if (!responseCallback) {
                       
                        return;
                    }
                    
                    responseCallback(message.responseData);
                    delete responseCallbacks[message.responseId];
                } else {
                    if (message.callbackId) {
                        var callbackResponseId = message.callbackId;
                        responseCallback = function(responseData) {
                            _doSend({ handlerName:message.handlerName, responseId:callbackResponseId, responseData:responseData });
                        };
                    }
                    var handler = messageHandlers[message.handlerName];
                    if (!handler) {
                        console.log("WebViewJavascriptBridge: WARNING: no handler for message from ObjC:", message);
                    } else {
                        handler(message.data, responseCallback);
                    }
                }
            }
        }
        function _handleMessageFromObjC(messageJSON) {
            _dispatchMessageFromObjC(messageJSON);
        }
    })(window);
                                                             ); // END preprocessorJSCode
    
#undef __WVJB_js_func__
    return preprocessorJSCode;
};


@end
