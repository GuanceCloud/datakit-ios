//
//  FTUncaughtExceptionHandler.h
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMSessionProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@class  FTMobileAgent;
@interface FTUncaughtExceptionHandler : NSObject
@property (nonatomic,weak) id<FTRUMSessionErrorDelegate> errorDelegate;

+ (instancetype)sharedHandler;

@end

NS_ASSUME_NONNULL_END
