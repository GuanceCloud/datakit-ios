//
//  FTURLProtocol.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FTHTTPProtocolDelegate;
@interface FTURLProtocol : NSURLProtocol

+ (void)startMonitor;

+ (void)stopMonitor;
+ (void)setDelegate:(id<FTHTTPProtocolDelegate>)newValue;

+ (id<FTHTTPProtocolDelegate>)delegate;

@end
@protocol FTHTTPProtocolDelegate <NSObject>
@optional
- (void)ftHTTPProtocolResponseData:(NSData *)data task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0));
- (void)ftHTTPProtocol:(FTURLProtocol *)protocol didCompleteWithError:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
