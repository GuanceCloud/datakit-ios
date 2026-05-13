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
@class FTSRWebViewWireframe,FTUIImageResource,FTSRImageWireframe;
@interface FTSessionReplayWireframesBuilder : NSObject
@property (nonatomic, strong) NSMutableArray<id<FTSRResource>> *resources;
-(instancetype)initWithResources:(NSArray<id <FTSRResource>>*)resources webViewSlotIDs:( NSSet<NSNumber *> *)webViewSlotIDs;

- (void)addResources:(NSArray<id <FTSRResource>>*)resources;
- (FTSRWireframe *)createShapeWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes;

- (FTSRImageWireframe *)createImageWireframeWithID:(int64_t)identifier resource:(id<FTSRResource>)resource frame:(CGRect)frame clip:(CGRect)clip;

- (FTSRWebViewWireframe *)visibleWebViewWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes linkRUMKeysInfo:(nullable NSDictionary *)linkRUMKeysInfo;
- (NSArray<FTSRWireframe*>*)hiddenWebViewWireframes;

- (NSSet<NSNumber *> *)hiddenWebViewSlotIDs;
- (NSDictionary *)linkRumKeysInfo;
@end

NS_ASSUME_NONNULL_END
