//
//  FTDataWriterManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/26.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
