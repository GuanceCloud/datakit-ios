//
//  FTSessionReplayFeature.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTFeature.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTRemoteFeature,FTWriter;
@class FTSessionReplayConfig;
@interface FTSessionReplayFeature : NSObject<FTRemoteFeature>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) PerformancePresetOverride *performanceOverride;
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;
@property (nonatomic, strong) id<FTWriter> writer;
@property ()
-(instancetype)initWithConfig:(FTSessionReplayConfig *)config;
@end

NS_ASSUME_NONNULL_END
