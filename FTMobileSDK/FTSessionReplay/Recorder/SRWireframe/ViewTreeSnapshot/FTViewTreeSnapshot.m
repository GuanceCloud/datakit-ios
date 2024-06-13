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

@implementation FTUnknownElement
@synthesize importance;
@synthesize nodes;
@synthesize resources;
@synthesize subtreeStrategy;

-(instancetype)init{
    self = [super init];
    if(self){
        importance = INT_MIN;
        subtreeStrategy = NodeSubtreeStrategyRecord;
    }
    return self;
}





@end
