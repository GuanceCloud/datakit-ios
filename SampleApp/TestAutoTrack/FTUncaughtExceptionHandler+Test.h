//
//  FTUncaughtExceptionHandler+Test.h
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/7.
//  Copyright © 2020 hll. All rights reserved.
//

#import <FTMobileAgent/FTUncaughtExceptionHandler.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTUncaughtExceptionHandler (Test)
@property (nonatomic, strong) NSHashTable *ftSDKInstances;
+ (NSArray *)backtrace;
@end

NS_ASSUME_NONNULL_END
