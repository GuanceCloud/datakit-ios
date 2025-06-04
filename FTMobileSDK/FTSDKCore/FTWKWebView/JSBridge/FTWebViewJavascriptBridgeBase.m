//
//  FTWebViewJavascriptBridgeBase.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/5.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTWebViewJavascriptBridgeBase.h"
#import "FTLog+Private.h"
@implementation FTWebViewJavascriptBridgeBase{
    long _uniqueId;
}
- (instancetype)init {
   if (self = [super init]) {
       self.messageHandlers = [NSMutableDictionary dictionary];
       self.responseCallbacks = [NSMutableDictionary dictionary];
       _uniqueId = 0;
   }
   return self;
}

- (void)sendData:(id)data responseCallback:(WVJBResponseCallback)responseCallback handlerName:(NSString*)handlerName {
   NSMutableDictionary* message = [NSMutableDictionary dictionary];
   
   if (data) {
       message[@"data"] = data;
   }
   
   if (responseCallback) {
       NSString* callbackId = [NSString stringWithFormat:@"objc_cb_%ld", ++_uniqueId];
       self.responseCallbacks[callbackId] = [responseCallback copy];
       message[@"callbackId"] = callbackId;
   }
   
   if (handlerName) {
       message[@"handlerName"] = handlerName;
   }
   [self _dispatchMessage:message];
}

- (void)flushMessageQueue:(NSString *)messageQueueString slotId:(NSUInteger)slotId{
   if (messageQueueString == nil || messageQueueString.length == 0) {
       FTInnerLogWarning(@"WebViewJavascriptBridge: WARNING: ObjC got nil while fetching the message queue JSON from webview. This can happen if the WebViewJavascriptBridge JS is not currently present in the webview, e.g if the webview just loaded a new page.");
       return;
   }

   id messages = [self _deserializeMessageJSON:messageQueueString];
   for (WVJBMessage* message in messages) {
       if (![message isKindOfClass:[WVJBMessage class]]) {
           FTInnerLogWarning(@"WebViewJavascriptBridge: WARNING: Invalid %@ received: %@", [message class], message);
           continue;
       }
       NSString* responseId = message[@"responseId"];
       if (responseId) {
           WVJBResponseCallback responseCallback = _responseCallbacks[responseId];
           responseCallback(message[@"responseData"]);
           [self.responseCallbacks removeObjectForKey:responseId];
       } else {
           WVJBResponseCallback responseCallback = NULL;
           NSString* callbackId = message[@"callbackId"];
           if (callbackId) {
               responseCallback = ^(id responseData) {
                   if (responseData == nil) {
                       responseData = [NSNull null];
                   }
                   
                   WVJBMessage* msg = @{ @"responseId":callbackId, @"responseData":responseData };
                   [self _dispatchMessage:msg];
               };
           } else {
               responseCallback = ^(id ignoreResponseData) {
                   // Do nothing
               };
           }
           
           WVJBHandler handler = self.messageHandlers[message[@"handlerName"]];
           
           if (!handler) {
               continue;
           }
           
           handler(message[@"data"],slotId,responseCallback);
       }
   }
}

- (NSString *)_serializeMessage:(id)message pretty:(BOOL)pretty{
   return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:message options:(NSJSONWritingOptions)(pretty ? NSJSONWritingPrettyPrinted : 0) error:nil] encoding:NSUTF8StringEncoding];
}

- (NSArray*)_deserializeMessageJSON:(NSString *)messageJSON {
   return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

- (void) _evaluateJavascript:(NSString *)javascriptCommand {
   [self.delegate _evaluateJavascript:javascriptCommand];
}

- (void)_dispatchMessage:(WVJBMessage*)message {
   NSString *messageJSON = [self _serializeMessage:message pretty:NO];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
   messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    //FTWebViewJavascriptBridge
   NSString* javascriptCommand = [NSString stringWithFormat:@"FTWebViewJavascriptBridge._handleMessageFromObjC('%@');", messageJSON];
   if ([[NSThread currentThread] isMainThread]) {
       [self _evaluateJavascript:javascriptCommand];

   } else {
       dispatch_sync(dispatch_get_main_queue(), ^{
           [self _evaluateJavascript:javascriptCommand];
       });
   }
}

@end
