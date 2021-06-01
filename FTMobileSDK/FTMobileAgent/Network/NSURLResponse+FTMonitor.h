//
//  NSURLResponse+FTMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/2.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLResponse (FTMonitor)
- (NSDictionary *)ft_getResponseDict;
- (NSDictionary *)ft_getResponseContentDictWithData:(nullable NSData *)data;
- (NSNumber *)ft_getResponseStatusCode;
- (nullable NSString *)ft_getResourceStatusGroup;
- (nullable NSError *)ft_getResponseError;

@end

NS_ASSUME_NONNULL_END
