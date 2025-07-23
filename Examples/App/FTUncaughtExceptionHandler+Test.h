//
//  FTUncaughtExceptionHandler+Test.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2020/9/7.
//  Copyright © 2020 hll. All rights reserved.
//

#import <FTUncaughtExceptionHandler.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTUncaughtExceptionHandler (Test)
@property (nonatomic, strong) NSHashTable *ftSDKInstances;
+ (NSArray *)backtrace;
- (NSString *)handleExceptionInfo:(NSException *)exception;
@end

NS_ASSUME_NONNULL_END
