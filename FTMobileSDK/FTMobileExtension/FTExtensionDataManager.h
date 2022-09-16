//
//  FTExtensionDataManager.h
//  FTMobileExtension
//
//  Created by hulilei on 2022/9/9.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTExtensionDataManager : NSObject

/**
 * @property
 *
 * @abstract
 * AppGroups Identifier 数组
 */
@property (nonatomic, strong) NSArray *groupIdentifierArray;

+ (instancetype)sharedInstance;
/**
 * @abstract
 * 获取 groupIdentifier 对应 Extension 当前缓存路径
 *
 * @param groupIdentifier AppGroups Identifier
 * @return 在 group 中的数据缓存路径
 */
- (NSString *)filePathForApplicationGroupIdentifier:(NSString *)groupIdentifier;
/**
 * @abstract
 * 给对应 groupIdentifier 添加事件
 *
 * @param eventType 事件类型
 * @param tags      事件属性
 * @param groupIdentifier AppGroups Identifier
 * 
 * @return 是否写入成功
 */
- (BOOL)writeEventType:(NSString *)eventType tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm groupIdentifier:(NSString *)groupIdentifier;
/**
 * @abstract
 * 读取 groupIdentifier 对应的所有缓存事件
 * @param groupIdentifier AppGroups Identifier
 * @return 当前 groupIdentifier 缓存的所有事件
 */
- (NSArray *)readAllEventsWithGroupIdentifier:(NSString *)groupIdentifier;

/**
 * @abstract
 * 删除 groupIdentifier 对应的所有缓存事件
 *
 * @param groupIdentifier AppGroups Identifier
 * @return 是否删除成功
 */
- (BOOL)deleteEventsWithGroupIdentifier:(NSString *)groupIdentifier;
@end

NS_ASSUME_NONNULL_END
