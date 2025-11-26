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
@class FTSRWebViewWireframe;
@interface FTSessionReplayWireframesBuilder : NSObject
-(instancetype)initWithResources:(NSArray<id <FTSRResource>>*)resources webViewSlotIDs:( NSSet<NSNumber *> *)webViewSlotIDs;

- (FTSRWireframe *)createShapeWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes;

- (FTSRWebViewWireframe *)visibleWebViewWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes linkRUMKeysInfo:(nullable NSDictionary *)linkRUMKeysInfo;
- (NSArray<FTSRWireframe*>*)hiddenWebViewWireframes;
- (NSDictionary *)linkRumKeysInfo;
@end

NS_ASSUME_NONNULL_END
