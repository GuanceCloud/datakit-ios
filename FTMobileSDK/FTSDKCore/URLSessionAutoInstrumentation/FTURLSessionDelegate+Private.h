//
//  FTURLSessionDelegate+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/11/15.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <FTMobileSDK/FTMobileSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTURLSessionDelegate ()
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request;
- (void)interceptTask:(NSURLSessionTask *)task;
@end

NS_ASSUME_NONNULL_END
