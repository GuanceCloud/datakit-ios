//
//  FTStackTraceBuilder.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTStackTrace.h"
#import "FTCrashStackCursor.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTStackTraceBuilder : NSObject
@property (nonatomic) BOOL symbolicate;

- (FTStackTrace *)buildStackTraceForCurrentThread;
- (nullable FTStackTrace *)buildStackTraceForCurrentThreadAsyncUnsafe;
- (FTStackTrace *)buildStackTraceFromStackEntries:(FTCrashStackEntry *)entries
                                           amount:(unsigned int)amount;
@end

NS_ASSUME_NONNULL_END
