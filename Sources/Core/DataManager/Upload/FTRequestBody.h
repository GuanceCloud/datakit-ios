//
//  FTRequestBody.h
//  FTSDK
//
//  Created by hulilei on 2021/8/5.
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
@class FTRecordModel;
NS_ASSUME_NONNULL_BEGIN
@protocol FTRequestBodyProtocol <NSObject>
- (NSString *)getRequestBodyWithEventArray:(NSArray *)events packageId:(NSString *)packageId enableIntegerCompatible:(BOOL)compatible;
@end
@interface FTRequestBody : NSObject

@end
@interface FTRequestLineBody : NSObject<FTRequestBodyProtocol>
@property (nonatomic, strong) NSArray <FTRecordModel *> *events;

@end
NS_ASSUME_NONNULL_END
