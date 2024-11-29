//
//  FTLongTaskManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"
#import "FTEnumConstant.h"
#import "FTRUMDependencies.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTRunloopDetectorDelegate <NSObject>
@optional
- (void)longTaskStackDetected:(NSString *)slowStack duration:(long long)duration time:(long long)time;
- (void)anrStackDetected:(NSString *)slowStack time:(NSDate *)time;
@end
@interface FTLongTaskManager : NSObject
-(instancetype)initWithDependencies:(FTRUMDependencies *)dependencies
                           delegate:(id<FTRunloopDetectorDelegate>)delegate
                  enableTrackAppANR:(BOOL)enableANR
               enableTrackAppFreeze:(BOOL)enableFreeze
                    blockDurationMs:(long)freezeThreshold;

-(void)shutDown;
@end

NS_ASSUME_NONNULL_END
