//
//  FTFeatureUpload.h
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/11.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@protocol FTReader,FTFeatureRequestBuilder,FTDataStore,FTCacheWriter;
@class FTPerformancePreset;
@interface FTFeatureUpload : NSObject
@property (nonatomic, assign) int maxBatchesPerUpload;


+(FTFeatureUpload *)createWithFeatureName:(NSString *)featureName
                               fileReader:(id<FTReader>)fileReader
                              cacheWriter:(id<FTCacheWriter>)cacheWriter
                           requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
                      maxBatchesPerUpload:(int)maxBatchesPerUpload
                              performance:(FTPerformancePreset *)performance
                                  context:(nonnull NSDictionary *)context;

-(instancetype)initWithFeatureName:(NSString *)featureName
                        fileReader:(id<FTReader>)fileReader
                       cacheWriter:(id<FTCacheWriter>)cacheWriter
                    requestBuilder:(id<FTFeatureRequestBuilder>)requestBuilder
               maxBatchesPerUpload:(int)maxBatchesPerUpload
                       performance:(FTPerformancePreset *)performance
                           context:(NSDictionary *)context;

@end

@interface FTImageFeatureUpload : FTFeatureUpload

@end
NS_ASSUME_NONNULL_END
