//
//  FTWeakPropertyContainer.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/2/20.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTWeakPropertyContainer.h"
@interface FTWeakPropertyContainer()
@property (nonatomic, weak) id weakProperty;

@end

@implementation FTWeakPropertyContainer

+ (instancetype)containerWithWeakProperty:(id)weakProperty {
   FTWeakPropertyContainer *container = [[FTWeakPropertyContainer alloc]init];
   container.weakProperty = weakProperty;
   return container;
}
@end
