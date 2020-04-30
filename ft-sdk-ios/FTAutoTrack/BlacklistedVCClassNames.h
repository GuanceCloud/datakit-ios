//
//  BlacklistedVCClassNames.h
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/4/30.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BlacklistedVCClassNames : NSObject
/**
 *  @abstract
 *  忽略的系统控制器
*/
+ (NSArray *)ft_blacklistedViewControllerClassNames;
@end

NS_ASSUME_NONNULL_END
