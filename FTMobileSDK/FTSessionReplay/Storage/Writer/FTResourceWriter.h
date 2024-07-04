//
//  FTResourceWriter.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTEnrichedResource,FTFeatureDataStore;
@protocol FTWriter;
@protocol FTResourcesWriting <NSObject>

- (void)write:(NSArray<FTEnrichedResource*>*)resources;

@end
@interface FTResourceWriter : NSObject<FTResourcesWriting>
@property (nonatomic, strong) id<FTWriter> writer;
- (instancetype)initWithWriter:(id<FTWriter>)writer dataStore:(FTFeatureDataStore *)dataStore;
@end

NS_ASSUME_NONNULL_END
