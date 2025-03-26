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

@end

NS_ASSUME_NONNULL_END
