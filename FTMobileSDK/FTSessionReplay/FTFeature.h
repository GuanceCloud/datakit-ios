//
//  FTFeature.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTFeature_h
#define FTFeature_h
@class FTPerformancePresetOverride;
@protocol FTFeatureRequestBuilder;
@protocol FTFeature <NSObject>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) FTPerformancePresetOverride *performanceOverride;
@end

@protocol FTRemoteFeature <NSObject,FTFeature>
@property (nonatomic, strong) id<FTFeatureRequestBuilder> requestBuilder;
@end
#endif /* FTFeature_h */
