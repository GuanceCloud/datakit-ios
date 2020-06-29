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
- (NSDictionary *)ft_getResponseContentDictWithData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
