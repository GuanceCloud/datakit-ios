//
//  FTRumTmpCacheWriter.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/21.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface FTRumTmpCacheWriter : NSObject<FTRUMDataCacheWriteProtocol>

- (BOOL)writeCacheDataWithErrorDate:(NSDate *)date;
@end

NS_ASSUME_NONNULL_END
