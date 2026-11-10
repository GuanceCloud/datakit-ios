//
//  FTEarlyCrash.h
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

// SDK-internal clock and occurrence classification. No file I/O or configuration.
#ifndef FTEarlyCrash_h
#define FTEarlyCrash_h
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
uint64_t ft_earlyCrashNow(void);
void ft_earlyCrashStart(uint64_t startNanoseconds);
uint64_t ft_earlyCrashStartTime(void);
bool ft_earlyCrashElapsed(uint64_t startNanoseconds, uint64_t captureNanoseconds, uint64_t * _Nullable elapsed);
#ifdef __OBJC__
@class NSString;
NSString * _Nullable ft_crashInstallPath(void);
#endif
#ifdef __cplusplus
}
#endif
#endif
