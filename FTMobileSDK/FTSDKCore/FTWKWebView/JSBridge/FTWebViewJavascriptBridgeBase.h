//
//  FTWebViewJavascriptBridgeBase.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/1/5.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTWebViewJavascriptBridgeBaseDelegate <NSObject>
- (void)_evaluateJavascript:(NSString*)javascriptCommand;
@end
typedef NSDictionary WVJBMessage;
typedef void (^WVJBResponseCallback)(id responseData);
typedef void (^WVJBHandler)(id data, WVJBResponseCallback responseCallback);
@interface FTWebViewJavascriptBridgeBase : NSObject
@property (nonatomic, weak) id<FTWebViewJavascriptBridgeBaseDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary *responseCallbacks;
@property (nonatomic, strong) NSMutableDictionary *messageHandlers;
- (void)flushMessageQueue:(NSString *)messageQueueString;
- (void)sendData:(nullable id)data responseCallback:(WVJBResponseCallback)responseCallback handlerName:(NSString*)handlerName;

@end

NS_ASSUME_NONNULL_END
