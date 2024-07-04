//
//  FTFeatureUpload.h
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/11.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@protocol FTReader,FTFeatureRequestBuilder;
@class FTPerformancePreset;
@interface FTFeatureUpload : NSObject
@property (nonatomic, assign) int maxBatchesPerUpload;
@property (nonatomic, strong) NSDictionary *baseProperty;
-(instancetype)initWithFeatureName:(NSString *)featureName
                        fileReader:(id<FTReader>)fileReader
                    requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
               maxBatchesPerUpload:(int)maxBatchesPerUpload
                       performance:(FTPerformancePreset *)performance;

@end

NS_ASSUME_NONNULL_END
