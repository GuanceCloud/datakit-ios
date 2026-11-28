//
//  FTSRNodeSemantics.h
//  SessionReplay
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//  Licensed under the Apache License, Version 2.0 (the "License");
//

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_OSX

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NodeSubtreeStrategy) {
    NodeSubtreeStrategyRecord,
    NodeSubtreeStrategyIgnore
};

@protocol FTSRNodeWireframesBuilder;

@interface FTSRNodeSemantics : NSObject
@property (nonatomic, assign) int importance;
@property (nonatomic, strong) NSArray<id<FTSRNodeWireframesBuilder>> *nodes;
@property (nonatomic, assign) NodeSubtreeStrategy subtreeStrategy;
- (instancetype)initWithSubtreeStrategy:(NodeSubtreeStrategy)subtreeStrategy;
@end

@interface FTUnknownElement : FTSRNodeSemantics
+ (instancetype)constant;
@end

@interface FTInvisibleElement : FTSRNodeSemantics
+ (instancetype)constant;
@end

@interface FTIgnoredElement : FTSRNodeSemantics
@end

@interface FTAmbiguousElement : FTSRNodeSemantics
@end

@interface FTSpecificElement : FTSRNodeSemantics
@end

NS_ASSUME_NONNULL_END

#endif
