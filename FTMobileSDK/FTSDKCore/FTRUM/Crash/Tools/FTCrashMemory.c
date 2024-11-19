//
//  FTCrashMemory.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTCrashMemory.h"

#include <mach/mach.h>

static inline int copySafely(const void *restrict const src, void *restrict const dst, const int byteCount)
{
    vm_size_t bytesCopied = 0;
    kern_return_t result =
        vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)byteCount, (vm_address_t)dst, &bytesCopied);
    if (result != KERN_SUCCESS) {
        return 0;
    }
    return (int)bytesCopied;
}

static inline int copyMaxPossible(const void *restrict const src, void *restrict const dst, const int byteCount)
{
    const uint8_t *pSrc = src;
    const uint8_t *pSrcMax = (uint8_t *)src + byteCount;
    const uint8_t *pSrcEnd = (uint8_t *)src + byteCount;
    uint8_t *pDst = dst;

    int bytesCopied = 0;

    // Short-circuit if no memory is readable
    if (copySafely(src, dst, 1) != 1) {
        return 0;
    } else if (byteCount <= 1) {
        return byteCount;
    }

    for (;;) {
        int copyLength = (int)(pSrcEnd - pSrc);
        if (copyLength <= 0) {
            break;
        }

        if (copySafely(pSrc, pDst, copyLength) == copyLength) {
            bytesCopied += copyLength;
            pSrc += copyLength;
            pDst += copyLength;
            pSrcEnd = pSrc + (pSrcMax - pSrc) / 2;
        } else {
            if (copyLength <= 1) {
                break;
            }
            pSrcMax = pSrcEnd;
            pSrcEnd = pSrc + copyLength / 2;
        }
    }
    return bytesCopied;
}

static char g_memoryTestBuffer[10240];
static inline bool isMemoryReadable(const void *const memory, const int byteCount)
{
    const int testBufferSize = sizeof(g_memoryTestBuffer);
    int bytesRemaining = byteCount;

    while (bytesRemaining > 0) {
        int bytesToCopy = bytesRemaining > testBufferSize ? testBufferSize : bytesRemaining;
        if (copySafely(memory, g_memoryTestBuffer, bytesToCopy) != bytesToCopy) {
            break;
        }
        bytesRemaining -= bytesToCopy;
    }
    return bytesRemaining == 0;
}

int ftmem_maxReadableBytes(const void *const memory, const int tryByteCount)
{
    const int testBufferSize = sizeof(g_memoryTestBuffer);
    const uint8_t *currentPosition = memory;
    int bytesRemaining = tryByteCount;

    while (bytesRemaining > testBufferSize) {
        if (!isMemoryReadable(currentPosition, testBufferSize)) {
            break;
        }
        currentPosition += testBufferSize;
        bytesRemaining -= testBufferSize;
    }
    bytesRemaining -= copyMaxPossible(currentPosition, g_memoryTestBuffer, testBufferSize);
    return tryByteCount - bytesRemaining;
}

bool ftmem_isMemoryReadable(const void *const memory, const int byteCount)
{
    return isMemoryReadable(memory, byteCount);
}

int ftmem_copyMaxPossible(const void *restrict const src, void *restrict const dst, const int byteCount)
{
    return copyMaxPossible(src, dst, byteCount);
}

bool ftmem_copySafely(const void *restrict const src, void *restrict const dst, const int byteCount)
{
    return copySafely(src, dst, byteCount);
}
