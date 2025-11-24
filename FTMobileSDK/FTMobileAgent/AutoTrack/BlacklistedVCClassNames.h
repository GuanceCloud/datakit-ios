//
//  BlacklistedVCClassNames.h
//  FTAutoTrack
//
//  Created by hulilei on 2020/4/30.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BlacklistedVCClassNames : NSObject
/**
 *  @abstract
 *  Ignored system controllers
*/
+ (NSDictionary *)ft_blacklistedViewControllerClassNames;
@end

NS_ASSUME_NONNULL_END
