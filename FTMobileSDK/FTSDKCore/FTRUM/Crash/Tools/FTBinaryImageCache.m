//
//  FTBinaryImageCache.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTBinaryImageCache.h"
#import "FTCrashBinaryImageCache.h"
#include "FTCrashUUIDConversion.h"
static void binaryImageWasAdded(const FTBinaryImage *image);

static void binaryImageWasRemoved(const FTBinaryImage *image);
@implementation FTBinaryImageInfo

@end
@interface FTBinaryImageCache()
@property (nonatomic,strong) NSMutableArray<FTBinaryImageInfo *> *cache;
@end
@implementation FTBinaryImageCache
+(void)initialize{
    if (self == [FTBinaryImageCache class]) {
        ft_startCache();
    }
}
- (void)start{
    _cache = [NSMutableArray array];
    ft_registerAddedCallback(&binaryImageWasAdded);
    ft_registerRemovedCallback(&binaryImageWasRemoved);
}
- (void)stop{
    ft_registerAddedCallback(NULL);
    ft_registerRemovedCallback(NULL);
    _cache = nil;
}
- (nullable FTBinaryImageInfo *)imageByAddress:(const uint64_t)address{
    @synchronized(self) {
        NSInteger index = [self indexOfImage:address];
        return index >= 0 ? _cache[index] : nil;
    }
}
- (NSInteger)indexOfImage:(uint64_t)address
{
    if (_cache == nil)
        return -1;

    NSInteger left = 0;
    NSInteger right = _cache.count - 1;

    while (left <= right) {
        NSInteger mid = (left + right) / 2;
        FTBinaryImageInfo *image = _cache[mid];

        if (address >= image.address && address < (image.address + image.size)) {
            return mid;
        } else if (address < image.address) {
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }

    return -1; // Address not found
}


+ (NSString *_Nullable)convertUUID:(const unsigned char *const)value{
    if (nil == value) {
        return nil;
    }

    char uuidBuffer[37];
    ft_convertBinaryImageUUID(value, uuidBuffer);
    return [[NSString alloc] initWithCString:uuidBuffer encoding:NSASCIIStringEncoding];
}
- (void)binaryImageAdded:(const FTBinaryImage *)image
{
    if (image == NULL) {
        //(@"The image is NULL. Can't add NULL to cache.");
        return;
    }

    if (image->name == NULL) {
        //(@"The image name was NULL. Can't add image to cache.");
        return;
    }

    NSString *imageName = [NSString stringWithCString:image->name encoding:NSUTF8StringEncoding];

    if (imageName == nil) {
        //(@"Couldn't convert the cString image name to an NSString. This could be  @"due to a different encoding than NSUTF8StringEncoding of the cString..");
        return;
    }

    FTBinaryImageInfo *newImage = [[FTBinaryImageInfo alloc] init];
    newImage.name = imageName;
    newImage.UUID = [FTBinaryImageCache convertUUID:image->uuid];
    newImage.address = image->address;
    newImage.vmAddress = image->vmAddress;
    newImage.size = image->size;

    @synchronized(self) {
        NSUInteger left = 0;
        NSUInteger right = _cache.count;

        while (left < right) {
            NSUInteger mid = (left + right) / 2;
            FTBinaryImageInfo *compareImage = _cache[mid];
            if (newImage.address < compareImage.address) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        [_cache insertObject:newImage atIndex:left];
    }
}

- (void)binaryImageRemoved:(const FTBinaryImage *)image
{
    if (image == NULL) {
        //(@"The image is NULL. Can't remove it from the cache.");
        return;
    }

    @synchronized(self) {
        NSInteger index = [self indexOfImage:image->address];
        if (index >= 0) {
            [_cache removeObjectAtIndex:index];
        }
    }
}
@end
static void
binaryImageWasAdded(const FTBinaryImage *image)
{
    
}

static void
binaryImageWasRemoved(const FTBinaryImage *image)
{
    
}
