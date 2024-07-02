//
//  FTResourceWriter.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTEnrichedResource;
@protocol FTWriter;
@protocol FTResourcesWriting <NSObject>

- (void)write:(NSArray<FTEnrichedResource*>*)resources;

@end
@interface FTResourceWriter : NSObject<FTResourcesWriting>
@property (nonatomic, strong) id<FTWriter> writer;

@end

NS_ASSUME_NONNULL_END
