//
//  FTViewTreeSnapshot.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/13.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTViewTreeSnapshot.h"

@implementation FTViewTreeSnapshot

@end
@implementation FTSRNodeSemantics
-(instancetype)initWithSubtreeStrategy:(NodeSubtreeStrategy)subtreeStrategy{
    self = [super init];
    if(self){
        _subtreeStrategy = subtreeStrategy;
    }
    return self;
}

@end
@implementation FTUnknownElement
+ (instancetype)constant{
    return [[FTUnknownElement alloc]init];
}
-(instancetype)init{
    self = [super init];
    if(self){
        self.importance = INT_MIN;
        self.subtreeStrategy = NodeSubtreeStrategyRecord;
    }
    return self;
}
@end

@implementation FTInvisibleElement

+ (instancetype)constant{
    return [[FTInvisibleElement alloc]init];
}
-(instancetype)init{
    return [self initWithSubtreeStrategy:NodeSubtreeStrategyIgnore];
}
-(instancetype)initWithSubtreeStrategy:(NodeSubtreeStrategy)subtreeStrategy{
    self = [super initWithSubtreeStrategy:subtreeStrategy];
    if(self){
        self.importance = 0;
    }
    return self;
}
@end

@implementation FTIgnoredElement

-(instancetype)initWithSubtreeStrategy:(NodeSubtreeStrategy)subtreeStrategy{
    self = [super initWithSubtreeStrategy:subtreeStrategy];
    if(self){
        self.importance = INT_MAX;
    }
    return self;
}

@end

@implementation FTAmbiguousElement
-(instancetype)init{
    self = [super initWithSubtreeStrategy:NodeSubtreeStrategyRecord];
    self.importance = 0;
    return self;
}
@end

@implementation FTSpecificElement

-(instancetype)initWithSubtreeStrategy:(NodeSubtreeStrategy)subtreeStrategy{
    self = [super initWithSubtreeStrategy:subtreeStrategy];
    if(self){
        self.importance = INT_MAX;
    }
    return self;
}
@end

#endif
