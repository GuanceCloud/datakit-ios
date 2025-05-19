//
//  FTTmpCacheManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/19.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTFileWriter.h"
NS_ASSUME_NONNULL_BEGIN
@class FTDirectory;

@interface FTTmpCacheManager : NSObject<FTCacheWriter>
- (instancetype)initWithCacheFileWriter:(id<FTWriter>)cacheWriter cacheDirectory:(FTDirectory *)cacheDirectory directory:(FTDirectory *)directory queue:(dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END
