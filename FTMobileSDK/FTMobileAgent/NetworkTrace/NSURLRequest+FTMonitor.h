//
//  NSURLRequest+FTMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest (FTMonitor)
@property (nonatomic, strong) NSDate *ftRequestStartDate;
- (NSDictionary *)ft_getRequestContentDict;
- (NSString *)ft_getBodyData:(BOOL)allow;
- (NSString *)ft_getOperationName;
- (NSString *)ft_getNetworkTraceId;
- (NSString *)ft_getNetworkSpanID;
- (NSURLRequest *)ft_NetworkTrace;
- (BOOL)ft_isAllowedContentType;
- (NSDictionary *)ft_getRequestHeaders;
@end

NS_ASSUME_NONNULL_END
