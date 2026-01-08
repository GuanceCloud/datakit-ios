//
//  FTCrashBacktrace.c
//
// Created by Alexander Cohen on 2025-05-27.
//
// Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

#include "FTCrashBacktrace.h"

#include <sys/param.h>

#include "FTCrashBinaryImageCache.h"
#include "FTCrashDynamicLinker.h"
#include "FTCrashStackCursor.h"
#include "FTCrashStackCursor_MachineContext.h"
#include "FTCrashStackCursor_SelfThread.h"
#include "FTCrashSymbolicator.h"
#include "FTCrashThread.h"

int ftcrashbt_captureBacktrace(pthread_t thread, uintptr_t *addresses, int count)
{
    if (!addresses || count == 0) {
        return 0;
    }

    FTCrashMachineContext machineContext = { 0 };
    FTCrashStackCursor stackCursor = {};
    int maxFrames = MIN(count, FTCRASHSC_MAX_STACK_DEPTH);

    if (thread == pthread_self()) {
        ftcrashsc_initSelfThread(&stackCursor, 0);
    } else {
        const thread_t machThread = pthread_mach_thread_np(thread);
        if (machThread == MACH_PORT_NULL) {
            return 0;
        }
        if (!ftcrashmc_getContextForThread(machThread, &machineContext, false)) {
            return 0;
        }
        ftcrashsc_initWithMachineContext(&stackCursor, maxFrames, &machineContext);
    }

    int frameCount = 0;
    while (frameCount < maxFrames && stackCursor.advanceCursor(&stackCursor)) {
        addresses[frameCount++] = stackCursor.stackEntry.address;
    }

    return frameCount;
}

bool ftcrashbt_symbolicateAddress(uintptr_t address, struct FTCrashSymbolInformation *result)
{
    if (!result) {
        return false;
    }

    // initalize the binary image cache.
    // this has an atomic check so isn't expensive
    // except for the first call.
    ftcrashbic_init();

    uintptr_t untaggedAddress = ftcrashsymbolicator_callInstructionAddress(address);

    Dl_info info = {};
    if (ftcrashdl_dladdr(untaggedAddress, &info) == false) {
        return false;
    }

    FTCrashBinaryImage image = {};
    if (ftcrashdl_binaryImageForHeader(info.dli_fbase, info.dli_fname, &image) == false) {
        return false;
    }

    result->returnAddress = address;
    result->callInstruction = untaggedAddress;
    result->symbolAddress = (uintptr_t)info.dli_saddr;
    result->symbolName = info.dli_sname;
    result->imageName = info.dli_fname;
    result->imageAddress = (uintptr_t)info.dli_fbase;
    result->imageSize = image.size;
    result->imageUUID = image.uuid;
    result->cpuType = image.cpuType;
    result->cpuSubType = image.cpuSubType;
    return true;
}
