//
//  FTDataStorage.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTPerformancePreset,FTDirectory;
NS_ASSUME_NONNULL_BEGIN
@protocol FTWriter,FTReader;
@interface FTFeatureStorage : NSObject
-(instancetype)initWithFeatureName:(NSString *)featureName
                             queue:(dispatch_queue_t)queue
                         directory:(FTDirectory *)directory
                       performance:(FTPerformancePreset *)performance;
- (id<FTWriter>)writer;
- (id<FTReader>)reader;
- (void)clearAllData;
- (void)setIgnoreFilesAgeWhenReading:(BOOL)ignore;
@end

NS_ASSUME_NONNULL_END
