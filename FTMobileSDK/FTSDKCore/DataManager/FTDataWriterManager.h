//
//  FTDataWriterManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/26.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"
#import "FTLoggerDataWriteProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTDataWriterManager : NSObject<FTRUMDataWriteProtocol,FTLoggerDataWriteProtocol>

/// 初始化方法，支持设置 rum 采集 error Session 发生 error 前时间间隔，默认 60
/// - Parameter timeInterval: 时间间隔
-(instancetype)initWithCacheInvalidTimeInterval:(NSTimeInterval)timeInterval;
@end

NS_ASSUME_NONNULL_END
