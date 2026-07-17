//
//  FTLoggerDataWriteProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/5/26.
//  Copyright 2023 Shanghai Guance Information Technology Co., Ltd.
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

#ifndef FTLoggerDataWriteProtocol_h
#define FTLoggerDataWriteProtocol_h
NS_ASSUME_NONNULL_BEGIN
/// RUM data write interface
@protocol FTLoggerDataWriteProtocol <NSObject>

/// Logger data write
/// - Parameters:
///   - tags: Properties
///   - field: Metrics
///   - time: Data generation timestamp (ns)
-(void)loggingTags:(nullable NSDictionary *)tags field:(nullable NSDictionary *)field time:(long long)time linkRum:(BOOL)linkRum;

@end
NS_ASSUME_NONNULL_END

#endif /* FTLoggerDataWriteProtocol_h */
