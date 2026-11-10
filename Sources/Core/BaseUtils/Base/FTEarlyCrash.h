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

// SDK-internal launch policy. No host application configuration is exposed.
#ifndef FTEarlyCrash_h
#define FTEarlyCrash_h
#include <stdint.h>
#include <stdbool.h>
#include <dispatch/dispatch.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct FTEarlyCrashState FTEarlyCrashState;
uint64_t ft_earlyCrashNow(void);
// Start capture does no I/O. Both independent file operations share this queue.
dispatch_queue_t ft_earlyCrashPreparationQueue(void);
void ft_earlyCrashStart(uint64_t startNanoseconds);
uint64_t ft_earlyCrashStartTime(void);
// Asynchronous entry points: upload loads history; Crash enables recording.
void ft_earlyCrashLoadHistory(void);
void ft_earlyCrashEnableRecording(void);
// Queue-owned C operations used by the shared file helper.
void ft_earlyCrashRestoreHistory(const char *markerPath);
void ft_earlyCrashPrepareRecording(const char *markerPath);
#ifdef __OBJC__
@class NSString;
NSString * _Nullable ft_crashInstallPath(void);
#endif
void ft_earlyCrashBegin(uint64_t startNanoseconds, const char *markerPath);
void ft_earlyCrashRecord(uint64_t eventNanoseconds);
unsigned ft_earlyCrashTakeUploadDelay(void);
// Instance functions allow isolated launches/clocks without resetting production globals.
// History recovery and recording preparation have one serial owner; start and
// record may run concurrently. Restoring history does not prepare a writer.
// Destroy requires that all callers have finished. A pre-ready delay read returns
// the default without consuming the first-upload allowance.
FTEarlyCrashState *ft_earlyCrashCreate(void);
void ft_earlyCrashDestroy(FTEarlyCrashState *state);
void ft_earlyCrashStartInState(FTEarlyCrashState *state, uint64_t startNanoseconds);
void ft_earlyCrashRestoreHistoryInState(FTEarlyCrashState *state, const char *markerPath);
void ft_earlyCrashPrepareRecordingInState(FTEarlyCrashState *state, const char *markerPath);
void ft_earlyCrashInitialize(FTEarlyCrashState *state, uint64_t startNanoseconds, const char *markerPath);
void ft_earlyCrashRecordInState(FTEarlyCrashState *state, uint64_t eventNanoseconds);
unsigned ft_earlyCrashTakeDelayInState(FTEarlyCrashState *state);
#ifdef __cplusplus
}
#endif
#endif
