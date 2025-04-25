//
//  FTSessionReplayWireframesBuilder.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/21.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSRNodeWireframesBuilder.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTSessionReplayWireframesBuilder : NSObject
-(instancetype)initWithResources:(NSArray<id <FTSRResource>>*)resources webViewSlotIDs:( NSSet<NSNumber *> *)webViewSlotIDs;

- (FTSRWireframe *)createShapeWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes;

- (FTSRWireframe *)visibleWebViewWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes;
- (NSArray<FTSRWireframe*>*)hiddenWebViewWireframes;
@end

NS_ASSUME_NONNULL_END
