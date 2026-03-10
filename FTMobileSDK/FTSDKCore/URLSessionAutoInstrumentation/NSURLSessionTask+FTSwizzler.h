//
//  NSURLSessionTask+FTSwizzler.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/1/2.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLSessionTask (FTSwizzler)
@property (nonatomic, assign) BOOL ft_hasCompletion;

- (id<NSURLSessionDelegate>)ft_delegate;
@end

NS_ASSUME_NONNULL_END
