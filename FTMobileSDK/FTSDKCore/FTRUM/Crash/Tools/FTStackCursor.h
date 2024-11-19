//
//  FTStackCursor.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTStackCursor_h
#define FTStackCursor_h

#include <stdbool.h>
#include <sys/types.h>

#include "FTCrashMachineContext.h"

#ifdef __cplusplus
extern "C" {
#endif
#define FTSC_CONTEXT_SIZE 100

/** Point at which to give up walking a stack and consider it a stack overflow. */
#define FTSC_STACK_OVERFLOW_THRESHOLD 150
typedef struct {
    /** Current address in the stack trace. */
    uintptr_t address;

    /** The name (if any) of the binary image the current address falls inside. */
    const char *imageName;

    /** The starting address of the binary image the current address falls inside. */
    uintptr_t imageAddress;

    /** The name (if any) of the closest symbol to the current address. */
    const char *symbolName;

    /** The address of the closest symbol to the current address. */
    uintptr_t symbolAddress;
} FTStackEntry;
typedef struct FTStackCursor {
    FTStackEntry stackEntry;

    struct {
        /** Current depth as we walk the stack (1-based). */
        int currentDepth;

        /** If true, cursor has given up walking the stack. */
        bool hasGivenUp;
    } state;

    /** Reset the cursor back to the beginning. */
    void (*resetCursor)(struct FTStackCursor *);

    /** Advance the cursor to the next stack entry. */
    bool (*advanceCursor)(struct FTStackCursor *);

    /** Attempt to symbolicate the current address, filling in the fields in stackEntry. */
    bool (*symbolicate)(struct FTStackCursor *);

    /** Internal context-specific information. */
    void *context[FTSC_CONTEXT_SIZE];
} FTStackCursor;


void ftsc_initCursor(FTStackCursor *cursor, void (*resetCursor)(FTStackCursor *),
                    bool (*advanceCursor)(FTStackCursor *));

/** Reset a cursor.
*  INTERNAL METHOD. Do not call!
*
* @param cursor The cursor to reset.
*/
void ftsc_resetCursor(FTStackCursor *cursor);
#ifdef __cplusplus
}
#endif
#endif /* FTStackCursor_h */
