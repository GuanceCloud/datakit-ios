//
//  FTStackCursor_SelfThread.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTStackCursor_SelfThread.h"
#include <execinfo.h>
#include "FTStackCursor_Backtrace.h"

#define MAX_BACKTRACE_LENGTH (FTSC_CONTEXT_SIZE - sizeof(FTStackCursor_Backtrace_Context) / sizeof(void *) - 1)
typedef struct {
    FTStackCursor_Backtrace_Context SelfThreadContextSpacer;
    uintptr_t backtrace[0];
} SelfThreadContext;
void ftsc_initSelfThread(FTStackCursor *cursor, int skipEntries) __attribute__((disable_tail_calls))
{
    SelfThreadContext *context = (SelfThreadContext *)cursor->context;
    int backtraceLength = backtrace((void **)context->backtrace, MAX_BACKTRACE_LENGTH);
    ftsc_initWithBacktrace(cursor, context->backtrace, backtraceLength, skipEntries + 1);
    __asm__ __volatile__("");  // thwart tail-call optimization
}
