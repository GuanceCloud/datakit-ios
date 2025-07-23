//
//  FTCrashMonitor.h
//  FTAutoTrack
//
//  Created by hulilei on 2020/1/6.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTErrorDataProtocol.h"
NS_ASSUME_NONNULL_BEGIN

/// Crash collection tool
@interface FTCrash : NSObject

/// Singleton
+ (instancetype)shared;
/// Add delegate object for handling error data
/// - Parameter delegate: delegate object
- (void)addErrorDataDelegate:(id <FTErrorDataDelegate>)delegate;
/// Remove delegate object for handling error data
/// - Parameter delegate: delegate object
- (void)removeErrorDataDelegate:(id <FTErrorDataDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
