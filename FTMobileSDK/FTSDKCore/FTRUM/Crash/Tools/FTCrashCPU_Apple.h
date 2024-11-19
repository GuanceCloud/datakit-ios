//
//  FTCrashCPU_Apple.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashCPU_Apple_h
#define FTCrashCPU_Apple_h
#ifdef __cplusplus
extern "C" {
#endif

#include <mach/mach_types.h>
bool
ftcrashcpu_i_fillState(const thread_t thread, const thread_state_t state,
                       const thread_state_flavor_t flavor, const mach_msg_type_number_t stateCount);

#ifdef __cplusplus
}
#endif
#endif /* FTCrashCPU_Apple_h */
