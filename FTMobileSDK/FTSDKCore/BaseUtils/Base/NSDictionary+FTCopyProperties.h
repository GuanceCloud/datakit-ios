//
//  NSDictionary+FTCopyProperties.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (FTCopyProperties)
- (NSDictionary *)ft_deepCopy;
@end

NS_ASSUME_NONNULL_END
