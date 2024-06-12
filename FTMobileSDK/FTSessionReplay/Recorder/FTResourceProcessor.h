//
//  FTResourceProcessor.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTSRResource;
@class FTSRContext;
@interface FTResourceProcessor : NSObject
@property (nonatomic, strong) dispatch_queue_t queue;
- (void)process:(NSArray<id<FTSRResource>> *)resources context:(FTSRContext *)context;
@end

NS_ASSUME_NONNULL_END
