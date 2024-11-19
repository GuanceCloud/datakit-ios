//
//  FTStackCursor_Backtrace.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/19.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTStackCursor_Backtrace_h
#define FTStackCursor_Backtrace_h

#include "FTStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Exposed for other internal systems to use.
 */
typedef struct {
    int skippedEntries;
    int backtraceLength;
    const uintptr_t *backtrace;
} FTStackCursor_Backtrace_Context;

/** Initialize a stack cursor for an existing backtrace (array of addresses).
 *
 * @param cursor The stack cursor to initialize.
 *
 * @param backtrace The existing backtrace to walk.
 *
 * @param backtraceLength The length of the backtrace.
 *
 * @param skipEntries The number of stack entries to skip.
 */
void ftsc_initWithBacktrace(FTStackCursor *cursor, const uintptr_t *backtrace,
    int backtraceLength, int skipEntries);

#ifdef __cplusplus
}
#endif

#endif /* FTStackCursor_Backtrace_Context_h */
