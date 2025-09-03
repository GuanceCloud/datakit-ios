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
@protocol FTRemoteFeature,FTWriter,FTDataStore,FTCacheWriter;
@class FTSessionReplayConfig;
@interface FTSessionReplayFeature : NSObject<FTRemoteFeature>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) FTPerformancePresetOverride *performanceOverride;
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;

-(instancetype)initWithConfig:(FTSessionReplayConfig *)config;
-(void)startWithWriter:(id<FTWriter>)writer
           cacheWriter:(id<FTCacheWriter>)cacheWriter
         webViewWriter:(id<FTWriter>)webViewWriter
        resourceWriter:(nullable id<FTWriter>)resourceWriter
     resourceDataStore:(nullable id<FTDataStore>)dataStore;
@end

NS_ASSUME_NONNULL_END
