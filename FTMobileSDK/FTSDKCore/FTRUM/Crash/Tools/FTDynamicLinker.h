//
//  FTDynamicLinker.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTDynamicLinker_h
#define FTDynamicLinker_h
#ifdef __cplusplus
extern "C" {
#endif

#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>

bool ftdl_dladdr(const uintptr_t address, Dl_info *const info);

#ifdef __cplusplus
}
#endif

#endif /* FTDynamicLinker_h */
