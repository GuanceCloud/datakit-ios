//
//  FTNodesFlattener.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/31.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSRWireframesBuilder.h"
NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot;
@interface FTNodesFlattener : NSObject
- (NSArray<id <FTSRWireframesBuilder>>*)flattenNodes:(FTViewTreeSnapshot *)snapShot;
@end

NS_ASSUME_NONNULL_END
