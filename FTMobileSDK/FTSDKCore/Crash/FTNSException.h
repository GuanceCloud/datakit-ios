//
//  FTNSException.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/1/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTNSException_h
#define FTNSException_h


#ifdef __cplusplus
extern "C" {
#endif
#include "FTStackInfo.h"

void installUncaughtExceptionHandler(const FTCrashNotifyCallback onCrashNotify);

void uninstallUncaughtExceptionHandler(void);


#ifdef __cplusplus
}
#endif

#endif /* FTNSException_h */
