//
//  FTCrashDynamicLinker.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashDynamicLinker_h
#define FTCrashDynamicLinker_h

#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint64_t address;
    uint64_t vmAddress;
    uint64_t size;
    const char *name;
    const uint8_t *uuid;
    int cpuType;
    int cpuSubType;
    uint64_t majorVersion;
    uint64_t minorVersion;
    uint64_t revisionVersion;
    const char *crashInfoMessage;
    const char *crashInfoMessage2;
    const char *crashInfoBacktrace;
    const char *crashInfoSignature;
} FTBinaryImage;

/** Get the number of loaded binary images.
 */
int ftdl_imageCount(void);

/** Get information about a binary image.
 *
 * @param index The binary index.
 *
 * @param buffer A structure to hold the information.
 *
 * @return True if the image was successfully queried.
 */
bool ftdl_getBinaryImage(int index, FTBinaryImage *buffer);

/** Get information about a binary image based on mach_header.
 *
 * @param header_ptr The pointer to mach_header of the image.
 *
 * @param image_name The name of the image.
 *
 * @param buffer A structure to hold the information.
 *
 * @return True if the image was successfully queried.
 */
bool ftdl_getBinaryImageForHeader(const void *const header_ptr, const char *const image_name, FTBinaryImage *buffer,bool isCrash);

/** Find a loaded binary image with the specified name.
 *
 * @param imageName The image name to look for.
 *
 * @param exactMatch If true, look for an exact match instead of a partial one.
 *
 * @return the index of the matched image, or UINT32_MAX if not found.
 */
uint32_t ftdl_imageNamed(const char *const imageName, bool exactMatch);

/** Get the UUID of a loaded binary image with the specified name.
 *
 * @param imageName The image name to look for.
 *
 * @param exactMatch If true, look for an exact match instead of a partial one.
 *
 * @return A pointer to the binary (16 byte) UUID of the image, or NULL if it
 *         wasn't found.
 */
const uint8_t *ftdl_imageUUID(const char *const imageName, bool exactMatch);

/** async-safe version of dladdr.
 *
 * This method searches the dynamic loader for information about any image
 * containing the specified address. It may not be entirely successful in
 * finding information, in which case any fields it could not find will be set
 * to NULL.
 *
 * Unlike dladdr(), this method does not make use of locks, and does not call
 * async-unsafe functions.
 *
 * @param address The address to search for.
 * @param info Gets filled out by this function.
 * @return true if at least some information was found.
 */
bool ftdl_dladdr(const uintptr_t address, Dl_info *const info);

#ifdef __cplusplus
}
#endif

#endif /* FTCrashDynamicLinker_h */
