//
//  FTCrashMemory.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashMemory_h
#define FTCrashMemory_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Test if the specified memory is safe to read from.
 *
 * @param memory A pointer to the memory to test.
 * @param byteCount The number of bytes to test.
 *
 * @return True if the memory can be safely read.
 */
bool ftmem_isMemoryReadable(const void *const memory, const int byteCount);

/** Test how much memory is readable from the specified pointer.
 *
 * @param memory A pointer to the memory to test.
 * @param tryByteCount The number of bytes to test.
 *
 * @return The number of bytes that are readable from that address.
 */
int ftmem_maxReadableBytes(const void *const memory, const int tryByteCount);

/** Copy memory safely. If the memory is not accessible, returns false
 * rather than crashing.
 *
 * @param src The source location to copy from.
 *
 * @param dst The location to copy to.
 *
 * @param byteCount The number of bytes to copy.
 *
 * @return true if successful.
 */
bool ftmem_copySafely(const void *restrict const src, void *restrict const dst, int byteCount);

/** Copies up to numBytes of data from src to dest, stopping if memory
 * becomes inaccessible.
 *
 * @param src The source location to copy from.
 *
 * @param dst The location to copy to.
 *
 * @param byteCount The number of bytes to copy.
 *
 * @return The number of bytes actually copied.
 */
int ftmem_copyMaxPossible(const void *restrict const src, void *restrict const dst, int byteCount);

#ifdef __cplusplus
}
#endif
#endif /* FTCrashMemory_h */
