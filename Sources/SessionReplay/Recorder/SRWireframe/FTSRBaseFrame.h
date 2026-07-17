//
//  FTSRBaseFrame.h
//  SessionReplay
//
//  Created by hulilei on 2023/8/7.
//
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
#import "FTJSONKeyMapper.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTAbstractJSONModelProtocol <NSObject>
- (NSDictionary *)toDictionary;
- (NSString*)toJSONString;
- (NSData*)toJSONData;
@end
/// Only supports basic types, NSArray, NSString, NSNumber
@interface FTSRBaseFrame : NSObject<NSCoding,NSSecureCoding,FTAbstractJSONModelProtocol>
+ (nullable FTJSONKeyMapper *)keyMapper;
@end

@interface FTSRBaseFrameProperty : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) Class type;
@property (copy, nonatomic) NSString *protocol;
@end
NS_ASSUME_NONNULL_END

#endif
