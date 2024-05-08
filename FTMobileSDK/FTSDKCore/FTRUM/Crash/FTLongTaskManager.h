//
//  FTLongTaskManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"

@protocol FTRunloopDetectorDelegate <NSObject>
@optional
- (void)longTaskStackDetected:(NSString*)slowStack duration:(long long)duration time:(long long)time;
- (void)anrStackDetected:(NSString*)slowStack;
@end
NS_ASSUME_NONNULL_BEGIN

@interface FTLongTaskManager : NSObject
-(instancetype)initWithDelegate:(id<FTRunloopDetectorDelegate>)delegate writer:(id<FTRUMDataWriteProtocol>)writer enableTrackAppANR:(BOOL)enableANR enableTrackAppFreeze:(BOOL)enableFreeze;
@end

NS_ASSUME_NONNULL_END
