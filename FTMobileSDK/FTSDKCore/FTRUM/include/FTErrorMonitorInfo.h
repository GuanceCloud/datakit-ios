//
//  FTErrorMonitorInfo.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/9.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTEnumConstant.h"
#import "FTErrorDataProtocol.h"
NS_ASSUME_NONNULL_BEGIN
typedef void (^ErrorMonitorInfoChangeBlock)(NSDictionary *info);

@protocol FTErrorMonitorInfoProvider <NSObject>

- (NSDictionary *)errorMonitorInfo;

- (void)onErrorMonitorInfoChange:(ErrorMonitorInfoChangeBlock)onChange;

@end
@interface FTErrorMonitorInfo : NSObject<FTErrorMonitorInfoWrapper,FTErrorMonitorInfoProvider>

- (instancetype)initWithMonitorType:(ErrorMonitorType)monitorType;
@end

NS_ASSUME_NONNULL_END
