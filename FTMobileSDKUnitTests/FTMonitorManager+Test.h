//
//  FTMonitorManager+Test.h
//  ft-sdk-iosTestUnitTests
//
//  Created by 胡蕾蕾 on 2020/8/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTMonitorManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTMonitorManager (Test)
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDictionary *monitorTagDict;
@property (nonatomic, copy) NSString *parentInstance;

@end

NS_ASSUME_NONNULL_END
