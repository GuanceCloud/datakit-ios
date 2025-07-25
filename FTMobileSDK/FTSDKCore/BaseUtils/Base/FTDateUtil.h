//
//  FTDateUtil.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/24.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTDateUtil : NSObject
+ (NSDate *)date;
/// Returns the absolute timestamp, which has no defined reference point or unit as it is platform dependent.（Nanosecond-level time）
+ (uint64_t)systemTime;
+ (NSTimeInterval)systemUptime;
@end

NS_ASSUME_NONNULL_END
