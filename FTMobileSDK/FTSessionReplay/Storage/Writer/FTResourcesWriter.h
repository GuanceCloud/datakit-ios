//
//  FTResourcesWriter.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTEnrichedResource,FTFeatureScope;
@protocol FTWriter,FTDataStore;
@protocol FTResourcesWriting <NSObject>

- (void)write:(NSArray<FTEnrichedResource*>*)resources;

@end
@interface FTResourcesWriter : NSObject<FTResourcesWriting>
- (instancetype)initWithFeatureScope:(FTFeatureScope *)featureScope dataStore:(nullable id<FTDataStore>)dataStore;
@end

NS_ASSUME_NONNULL_END
