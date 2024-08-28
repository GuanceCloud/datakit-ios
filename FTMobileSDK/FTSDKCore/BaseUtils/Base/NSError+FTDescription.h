//
//  NSError+FTDescription.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/27.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSError (FTDescription)
- (NSString *)ft_description;
@end

NS_ASSUME_NONNULL_END
