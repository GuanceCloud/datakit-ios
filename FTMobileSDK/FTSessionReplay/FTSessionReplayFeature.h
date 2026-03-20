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
@protocol FTRemoteFeature,FTWriter,FTDataStore,FTCacheWriter,FTScheduler;
@class FTSessionReplayConfig,FTFeatureStorage;
@interface FTSessionReplayFeature : NSObject<FTRemoteFeature>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) FTPerformancePresetOverride *performanceOverride;
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;

-(instancetype)initWithConfig:(FTSessionReplayConfig *)config;

-(void)startWithRecordStorage:(FTFeatureStorage *)recordStorage resourceWriter:(id <FTWriter>)resourceWriter resourceDataStore:(nullable id<FTDataStore>)dataStore;

- (void)startRecording;


@end

NS_ASSUME_NONNULL_END
