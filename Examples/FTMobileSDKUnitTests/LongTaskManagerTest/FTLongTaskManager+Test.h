//
//  FTLongTaskManager+Test.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/12.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "FTLongTaskManager.h"
#import "FTLongTaskANRData.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTLongTaskManager ()
@property (nonatomic, strong) FTLongTaskANRDataStore *anrDataStore;

- (void)updateLongTaskDate:(long long)time;
- (void)startLongTask:(long long)startTime;
- (void)endLongTask;
- (void)reportPreviousANRIfFound;
@end

NS_ASSUME_NONNULL_END
