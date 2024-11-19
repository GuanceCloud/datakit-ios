//
//  FTCrashBinaryImageCache.c
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#include "FTCrashBinaryImageCache.h"
#include "FTCrashDynamicLinker.h"
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
typedef struct FTCrashBinaryImageNode {
    FTBinaryImage image;
    bool available;
    struct FTCrashBinaryImageNode *next;
} FTCrashBinaryImageNode;

static FTCrashBinaryImageNode rootNode = { 0 };
static FTCrashBinaryImageNode *tailNode = NULL;
static pthread_mutex_t binaryImagesMutex = PTHREAD_MUTEX_INITIALIZER;

static ft_cacheChangeCallback imageAddedCallback = NULL;
static ft_cacheChangeCallback imageRemovedCallback = NULL;

static void
binaryImageAdded(const struct mach_header *header, intptr_t slide)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }
    pthread_mutex_unlock(&binaryImagesMutex);
    Dl_info info;
    if (!dladdr(header, &info) || info.dli_fname == NULL) {
        return;
    }

    FTBinaryImage binaryImage = { 0 };
    if (!ftdl_getBinaryImageForHeader(
            (const void *)header, info.dli_fname, &binaryImage, false)) {
        return;
    }

    FTCrashBinaryImageNode *newNode = malloc(sizeof(FTCrashBinaryImageNode));
    newNode->available = true;
    newNode->image = binaryImage;
    newNode->next = NULL;

    pthread_mutex_lock(&binaryImagesMutex);
    // Recheck tailNode as it could be null when
    // stopped from another thread.
    if (tailNode != NULL) {
        tailNode->next = newNode;
        tailNode = tailNode->next;
    } else {
        free(newNode);
        newNode = NULL;
    }
    pthread_mutex_unlock(&binaryImagesMutex);
    if (newNode && imageAddedCallback) {
        imageAddedCallback(&newNode->image);
    }
}

static void
binaryImageRemoved(const struct mach_header *header, intptr_t slide)
{
    FTCrashBinaryImageNode *nextNode = &rootNode;

    while (nextNode != NULL) {
        if (nextNode->image.address == (uint64_t)header) {
            nextNode->available = false;
            if (imageRemovedCallback) {
                imageRemovedCallback(&nextNode->image);
            }
            break;
        }
        nextNode = nextNode->next;
    }
}

void
ft_iterateOverImages(ft_imageIteratorCallback callback, void *context)
{
    /**
     We can't use locks here because this is meant to be used during crashes,
     where we can't use async unsafe functions. In order to avoid potential problems,
     we choose an approach that doesn't remove nodes from the list.
    */
    FTCrashBinaryImageNode *nextNode = &rootNode;

    // If tailNode is null it means the cache was stopped, therefore we end the iteration.
    // This will minimize any race condition effect without the need for locks.
    while (nextNode != NULL && tailNode != NULL) {
        if (nextNode->available) {
            callback(&nextNode->image, context);
        }
        nextNode = nextNode->next;
    }
}

void
ft_startCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode != NULL) {
        // Already initialized
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }
    tailNode = &rootNode;
    rootNode.next = NULL;
    pthread_mutex_unlock(&binaryImagesMutex);

    // During a call to _dyld_register_func_for_add_image() the callback func is called for every
    // existing image
    _dyld_register_func_for_add_image(&binaryImageAdded);
    _dyld_register_func_for_remove_image(&binaryImageRemoved);
}

void
ft_stopCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }

    FTCrashBinaryImageNode *node = rootNode.next;
    rootNode.next = NULL;
    tailNode = NULL;

    while (node != NULL) {
        FTCrashBinaryImageNode *nextNode = node->next;
        free(node);
        node = nextNode;
    }

    pthread_mutex_unlock(&binaryImagesMutex);
}

static void
initialReportToCallback(FTBinaryImage *image, void *context)
{
    ft_cacheChangeCallback callback = (ft_cacheChangeCallback)context;
    callback(image);
}

void
ft_registerAddedCallback(ft_cacheChangeCallback callback)
{
    imageAddedCallback = callback;
    if (callback) {
        pthread_mutex_lock(&binaryImagesMutex);
        ft_iterateOverImages(&initialReportToCallback, callback);
        pthread_mutex_unlock(&binaryImagesMutex);
    }
}

void
ft_registerRemovedCallback(ft_cacheChangeCallback callback)
{
    imageRemovedCallback = callback;
}
