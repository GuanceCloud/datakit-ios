//
//  FTRUMDataWriteProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/8/23.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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
#import "FTRUMWriteData.h"

#ifndef FTRUMDataWriteProtocol_h
#define FTRUMDataWriteProtocol_h
NS_ASSUME_NONNULL_BEGIN

/// RUM data write interface
@protocol FTRUMDataWriteProtocol <NSObject>

/// Required writer. Returns actual admission, not persistence or upload acknowledgment.
- (BOOL)writeRUMData:(FTRUMWriteData *)data;
@optional
/// Switch to cache writer for session on error data, data type is RUMCache
- (void)isCacheWriter:(BOOL)cache;

/// Whether the last APP has written local data for crashes, ANR, etc., errorDate is the crash time
- (void)lastFatalErrorIfFound:(long long)errorDate;

/// Process rum cache data, check if deletion is needed
- (void)checkRUMSessionOnErrorDatasWithExpireTime:(long long)expireTime;
@end
NS_ASSUME_NONNULL_END
#endif /* FTRUMDataWriteProtocol_h */
