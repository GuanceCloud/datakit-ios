//
//  FTViewTreeSnapshot.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

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
