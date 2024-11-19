//
//  FTStackCursor_Backtrace.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTStackCursor_Backtrace.h"
#include "FTCrashCPU.h"

static bool advanceCursor(FTStackCursor *cursor)
{
    FTStackCursor_Backtrace_Context *context = (FTStackCursor_Backtrace_Context *)cursor->context;
    int endDepth = context->backtraceLength - context->skippedEntries;
    if (cursor->state.currentDepth < endDepth) {
        int currentIndex = cursor->state.currentDepth + context->skippedEntries;
        uintptr_t nextAddress = context->backtrace[currentIndex];
        // Bug: The system sometimes gives a backtrace with an extra 0x00000001 at the end.
        if (nextAddress > 1) {
            cursor->stackEntry.address = ftcrashcpu_normaliseInstructionPointer(nextAddress);
            cursor->state.currentDepth++;
            return true;
        }
    }
    return false;
}
void ftsc_initWithBacktrace(FTStackCursor *cursor, const uintptr_t *backtrace,
                            int backtraceLength, int skipEntries){
    ftsc_initCursor(cursor, ftsc_resetCursor, advanceCursor);
    FTStackCursor_Backtrace_Context *context = (FTStackCursor_Backtrace_Context *)cursor->context;
    context->skippedEntries = skipEntries;
    context->backtraceLength = backtraceLength;
    context->backtrace = backtrace;
}
