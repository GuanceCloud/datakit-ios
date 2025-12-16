//
//  FTStackTraceBuilder.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTStackTraceBuilder.h"
#include "FTStackCursor_SelfThread.h"
#import "FTFrame.h"
#import "FTBinaryImageCache.h"

#define FT_HEX_ADDRESS_LENGTH 19

static inline NSString *
ft_snprintfHexAddress(uint64_t value)
{
    char buffer[FT_HEX_ADDRESS_LENGTH];
    snprintf(buffer, FT_HEX_ADDRESS_LENGTH, "0x%016llx", value);
    NSString *nsString = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
    return nsString;
}
@interface FTStackTraceBuilder()

@end
@implementation FTStackTraceBuilder
- (FTFrame *)crashStackEntryToFrame:(FTStackEntry)stackEntry
{
    FTFrame *frame = [[FTFrame alloc] init];

    if (stackEntry.symbolAddress != 0) {
        frame.symbolAddress = ft_snprintfHexAddress(stackEntry.symbolAddress);
    }

    frame.instructionAddress = ft_snprintfHexAddress(stackEntry.address);

    if (stackEntry.symbolName != NULL) {
        frame.function = [NSString stringWithCString:stackEntry.symbolName
                                            encoding:NSUTF8StringEncoding];
    }

    // If there is no symbolication, because debug was disabled
    // we get image from the cache.
    if (stackEntry.imageAddress == 0 && stackEntry.imageName == NULL) {
        FTBinaryImageInfo *info;

        frame.imageAddress = ft_snprintfHexAddress(info.address);
        frame.package = info.name;
    } else {
        frame.imageAddress = ft_snprintfHexAddress(stackEntry.imageAddress);

        if (stackEntry.imageName != NULL) {
            NSString *imageName = [NSString stringWithCString:stackEntry.imageName
                                                     encoding:NSUTF8StringEncoding];
            frame.package = imageName;
        }
    }

    return frame;
}
- (FTStackTrace *)retrieveStackTraceFromCursor:(FTStackCursor)stackCursor
{
    NSMutableArray<FTFrame *> *frames = [NSMutableArray array];
    FTFrame *frame = nil;
    while (stackCursor.advanceCursor(&stackCursor)) {
    
        if (self.symbolicate == NO || stackCursor.symbolicate(&stackCursor)) {
            frame = [self crashStackEntryToFrame:stackCursor.stackEntry];
            [frames addObject:frame];
        }
    }


    // The frames must be ordered from caller to callee, or oldest to youngest
    NSArray<FTFrame *> *framesReversed = [[frames reverseObjectEnumerator] allObjects];

    FTStackTrace *stacktrace = [[FTStackTrace alloc] initWithFrames:framesReversed];

    return stacktrace;
}
- (FTStackTrace *)buildStackTraceForCurrentThread{
    FTStackCursor stackCursor;
    // We don't need to skip any frames, because we filter out non sentry frames below.
    NSInteger framesToSkip = 0;
    ftcrashsc_initSelfThread(&stackCursor, (int)framesToSkip);

    return [self retrieveStackTraceFromCursor:stackCursor];
}
- (nullable FTStackTrace *)buildStackTraceForCurrentThreadAsyncUnsafe{
    return nil;
}

- (nonnull FTStackTrace *)buildStackTraceFromStackEntries:(FTStackEntry *)entries amount:(unsigned int)amount {
    return nil;
}

@end
