//
//  FTCrashBinaryImageCache.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashBinaryImageCache_h
#define FTCrashBinaryImageCache_h
 
#include "FTCrashDynamicLinker.h"
#include <stdio.h>

typedef void (*ft_imageIteratorCallback)(FTBinaryImage *, void *context);

typedef void (*ft_cacheChangeCallback)(const FTBinaryImage *binaryImage);

void ft_iterateOverImages(ft_imageIteratorCallback index, void *context);

/**
 * Starts the cache that will monitor binary image being loaded or removed.
 */
void ft_startCache(void);

/**
 * Stops the cache from monitoring binary image being loaded or removed.
 * This will also clean the cache.
 */
void ft_stopCache(void);

/**
 * Register a callback to be called every time a new binary image is added to the cache.
 * After register, this callback will be called for every image already in the cache,
 * this is a thread safe operation.
 */
void ft_registerAddedCallback(ft_cacheChangeCallback callback);

/**
 * Register a callback to be called every time a binary image is remove from the cache.
 */
void ft_registerRemovedCallback(ft_cacheChangeCallback callback);

#endif /* FTCrashBinaryImageCache_h */
