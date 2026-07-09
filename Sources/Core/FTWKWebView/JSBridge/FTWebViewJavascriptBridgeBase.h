//
//  FTWebViewJavascriptBridgeBase.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTWebViewJavascriptBridgeBaseDelegate <NSObject>
- (void)_evaluateJavascript:(NSString*)javascriptCommand;
@end
typedef NSDictionary WVJBMessage;
typedef void (^WVJBResponseCallback)(id responseData);
typedef void (^WVJBHandler)(id data, int64_t slotId,WVJBResponseCallback responseCallback);
@interface FTWebViewJavascriptBridgeBase : NSObject
@property (nonatomic, weak, nullable) id<FTWebViewJavascriptBridgeBaseDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary *responseCallbacks;
@property (nonatomic, strong) NSMutableDictionary *messageHandlers;
- (void)flushMessageQueue:(NSString *)messageQueueString slotId:(NSUInteger)slotId;
- (void)sendData:(nullable id)data responseCallback:(nullable WVJBResponseCallback)responseCallback handlerName:(NSString*)handlerName;

@end

NS_ASSUME_NONNULL_END
