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

#include "FTStackInfo.h"

void FTInstallMachException(void);

void FTUninstallMachException(void);

#ifdef __cplusplus
}
#endif
#endif /* FTMachException_h */
