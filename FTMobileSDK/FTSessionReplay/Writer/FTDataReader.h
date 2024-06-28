//
//  FTDataReader.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTReader.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTDataReader : NSObject<FTReader>
-(instancetype)initWithQueue:(dispatch_queue_t)queue fileReader:(id<FTReader>)fileReader;
@end

NS_ASSUME_NONNULL_END
