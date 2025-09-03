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
#import "FTUploadProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTDataWriterWorker : NSObject<FTRUMDataWriteProtocol,FTLoggerDataWriteProtocol,FTSessionOnErrorDataHandler>

/// Initialization method, supports setting the time interval before error occurs in rum collection error Session, default 60
/// - Parameter timeInterval: time interval
-(instancetype)initWithCacheInvalidTimeInterval:(NSTimeInterval)timeInterval;
@end

NS_ASSUME_NONNULL_END
