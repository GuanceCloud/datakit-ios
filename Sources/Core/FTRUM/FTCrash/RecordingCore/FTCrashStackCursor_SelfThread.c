//
//  FTCrashStackCursor_SelfThread.c
//
//  Copyright (c) 2016 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "FTCrashStackCursor_SelfThread.h"
#include <execinfo.h>

#include "FTCrashCompilerDefines.h"
#include "FTCrashStackCursor_Backtrace.h"

#define MAX_BACKTRACE_LENGTH (FTCRASHSC_CONTEXT_SIZE - sizeof(FTCrashStackCursor_Backtrace_Context) / sizeof(void *) - 1)
typedef struct {
    FTCrashStackCursor_Backtrace_Context SelfThreadContextSpacer;
    uintptr_t backtrace[0];
} SelfThreadContext;

void ftcrashsc_initSelfThread(FTCrashStackCursor *cursor, int skipEntries) FTCRASH_KEEP_FUNCTION_IN_STACKTRACE
{
    SelfThreadContext *context = (SelfThreadContext *)cursor->context;
    int backtraceLength = backtrace((void **)context->backtrace, MAX_BACKTRACE_LENGTH);
    ftcrashsc_initWithBacktrace(cursor, context->backtrace, backtraceLength, skipEntries + 1);
    FTCRASH_THWART_TAIL_CALL_OPTIMISATION
}
