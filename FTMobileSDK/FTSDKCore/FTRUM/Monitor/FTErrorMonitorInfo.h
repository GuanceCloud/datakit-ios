//
//  FTErrorMonitorInfo.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/9.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTEnumConstant.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTErrorMonitorInfo : NSObject
+ (NSDictionary *)errorMonitorInfo:(ErrorMonitorType)monitorType;
@end

NS_ASSUME_NONNULL_END
