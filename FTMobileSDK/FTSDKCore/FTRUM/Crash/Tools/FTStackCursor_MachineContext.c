//
//  FTStackCursor_MachineContext.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTStackCursor_MachineContext.h"
#include "FTCrashCPU.h"
#include "FTCrashMemory.h"
#include "FTStackCursor.h"
#include "FTCrashMachineContext.h"

typedef struct FrameEntry {
    /** The previous frame in the list. */
    struct FrameEntry *previous;

    /** The instruction address. */
    uintptr_t return_address;
} FrameEntry;

typedef struct {
    const struct FTCrashMachineContext *machineContext;
    int maxStackDepth;
    FrameEntry currentFrame;
    uintptr_t instructionAddress;
    uintptr_t linkRegister;
    bool isPastFramePointer;
} MachineContextCursor;
static bool advanceCursor(FTStackCursor *cursor)
{
    MachineContextCursor *context = (MachineContextCursor *)cursor->context;
    uintptr_t nextAddress = 0;

    if (cursor->state.currentDepth >= context->maxStackDepth) {
        cursor->state.hasGivenUp = true;
        return false;
    }

    if (context->instructionAddress == 0 && cursor->state.currentDepth == 0) {
        context->instructionAddress = ftcrashcpu_instructionAddress(context->machineContext);
        nextAddress = context->instructionAddress;
        goto successfulExit;
    }

    if (context->linkRegister == 0 && !context->isPastFramePointer) {
        // Link register, if available, is the second address in the trace.
        context->linkRegister = ftcrashcpu_linkRegister(context->machineContext);
        if (context->linkRegister != 0) {
            nextAddress = context->linkRegister;
            goto successfulExit;
        }
    }

    if (context->currentFrame.previous == NULL) {
        if (context->isPastFramePointer) {
            return false;
        }
        context->currentFrame.previous = (struct FrameEntry *)ftcrashcpu_framePointer(context->machineContext);
        context->isPastFramePointer = true;
    }

    if (!ftmem_copySafely(context->currentFrame.previous, &context->currentFrame, sizeof(context->currentFrame))) {
        return false;
    }
    if (context->currentFrame.previous == 0 || context->currentFrame.return_address == 0) {
        return false;
    }

    nextAddress = context->currentFrame.return_address;

successfulExit:
    cursor->stackEntry.address = ftcrashcpu_normaliseInstructionPointer(nextAddress);
    cursor->state.currentDepth++;
    return true;
}
static void resetCursor(FTStackCursor *cursor)
{
    ftsc_resetCursor(cursor);
    MachineContextCursor *context = (MachineContextCursor *)cursor->context;
    context->currentFrame.previous = 0;
    context->currentFrame.return_address = 0;
    context->instructionAddress = 0;
    context->linkRegister = 0;
    context->isPastFramePointer = 0;
}

void ftsc_initWithMachineContext(FTStackCursor *cursor, int maxStackDepth,
                                 const struct FTCrashMachineContext *machineContext){
    ftsc_initCursor(cursor, resetCursor, advanceCursor);
    MachineContextCursor *context = (MachineContextCursor *)cursor->context;
    context->machineContext = machineContext;
    context->maxStackDepth = maxStackDepth;
    context->instructionAddress = cursor->stackEntry.address;
}
