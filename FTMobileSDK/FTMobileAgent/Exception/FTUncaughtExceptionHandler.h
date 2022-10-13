//
//  FTUncaughtExceptionHandler.h
//  FTAutoTrack
//
//  Created by 胡蕾蕾 on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTErrorDataProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTUncaughtExceptionHandler : NSObject

+ (instancetype)sharedHandler;
- (void)addftSDKInstance:(id <FTErrorDataDelegate>)instance;
- (void)removeftSDKInstance:(id <FTErrorDataDelegate>)instance;
@end

NS_ASSUME_NONNULL_END
