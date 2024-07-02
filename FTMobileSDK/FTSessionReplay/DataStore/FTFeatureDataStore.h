//
//  FTFeatureDataStore.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/1.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTDataStore.h"
NS_ASSUME_NONNULL_BEGIN
@class FTDirectory;
@interface FTFeatureDataStore : NSObject<FTDataStore>
-(instancetype)initWithFeature:(NSString *)feature 
                         queue:(dispatch_queue_t)queue
                     directory:(FTDirectory *)directory;
@end

NS_ASSUME_NONNULL_END
