//
//  FTCrashDefaultMachineContextWrapper.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "FTCrashThread.h"
#import "FTCrashMachineContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTCrashDefaultMachineContextWrapper : NSObject
- (void)fillContextForCurrentThread:(struct FTCrashMachineContext *)context;
- (int)getThreadCount:(struct FTCrashMachineContext *)context;
- (FTCrashThread)getThread:(struct FTCrashMachineContext *)context withIndex:(int)index;
- (BOOL)getThreadName:(const FTCrashThread)thread
            andBuffer:(char *const)buffer
         andBufLength:(int)bufLength;
- (BOOL)isMainThread:(FTCrashThread)thread;
@end

NS_ASSUME_NONNULL_END
