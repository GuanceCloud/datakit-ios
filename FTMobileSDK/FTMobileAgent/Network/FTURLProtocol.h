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
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0));
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error;

// FTNetworkTrack
- (void)ftHTTPProtocolWithTask:(NSURLSessionTask *)task taskDuration:(NSNumber *)duration requestStartDate:(NSDate*)start responseData:(NSData *)data didCompleteWithError:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
