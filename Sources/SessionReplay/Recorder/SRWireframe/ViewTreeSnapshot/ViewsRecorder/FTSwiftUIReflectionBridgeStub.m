/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>

#if TARGET_OS_IOS && defined(GUANCE_COCOAPODS)

#import "FTSwiftUIReflectionBridge.h"

@implementation FTSwiftUIRecordingAttributes
@end

@implementation FTSwiftUIRecordingResult

- (NSArray *)wireframes {
    return @[];
}

- (NSArray *)resources {
    return @[];
}

@end

@implementation FTSwiftUIRenderer
@end

@implementation FTSwiftUIRecordingBuilder

- (nullable FTSwiftUIRecordingResult *)build {
    return nil;
}

@end

@implementation FTSwiftUIReflectionBridge

- (FTSwiftUIRecordingAttributes *)makeRecordingAttributes API_AVAILABLE(ios(13.0)) {
    return [FTSwiftUIRecordingAttributes new];
}

- (nullable FTSwiftUIRenderer *)rendererForHostingView:(UIView *)view API_AVAILABLE(ios(13.0)) {
    return nil;
}

- (nullable FTSwiftUIRecordingBuilder *)recordingBuilderForRenderer:(FTSwiftUIRenderer *)renderer attributes:(FTSwiftUIRecordingAttributes *)attributes API_AVAILABLE(ios(13.0)) {
    return nil;
}

@end

#endif
