//
//  FTMachException.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/12/28.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#ifndef FTMachException_h
#define FTMachException_h
#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <stdbool.h>
#include "FTStackInfo.h"

bool FTInstallMachException(const FTCrashNotifyCallback onCrashNotify);

void FTUninstallMachException(void);

#ifdef __cplusplus
}
#endif
#endif /* FTMachException_h */
