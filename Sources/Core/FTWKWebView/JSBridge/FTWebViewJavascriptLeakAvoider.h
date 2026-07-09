//
//  FTWebViewJavascriptLeakAvoider.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/1/6.
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
#import <TargetConditionals.h>
#if !TARGET_OS_TV
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTWebViewJavascriptLeakAvoider : NSObject<WKScriptMessageHandler>
@property(nonatomic,weak)id <WKScriptMessageHandler>  delegate;
- (instancetype)initWithDelegate:(id <WKScriptMessageHandler> )delegate;

@end

NS_ASSUME_NONNULL_END
#endif
