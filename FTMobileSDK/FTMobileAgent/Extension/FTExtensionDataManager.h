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

/// Extension component data management object
@interface FTExtensionDataManager : NSObject{
    NSArray * _groupIdentifierArray;
}
/// AppGroups Identifier array
@property (nonatomic, strong) NSArray *groupIdentifierArray;
/// Maximum storage data count
@property (nonatomic, assign) NSInteger maxCount;

/// Singleton
+ (instancetype)sharedInstance;

/// Get Extension current cache path for groupIdentifier
/// @param groupIdentifier AppGroups Identifier
/// @return Data cache path in group
- (nullable NSString *)filePathForApplicationGroupIdentifier:(NSString *)groupIdentifier;

/// Store mobileConfig
/// @param mobileConfig Mobile configuration items
-(void)writeMobileConfig:(NSDictionary *)mobileConfig;

/// Store rumConfig
/// @param rumConfig RUM configuration items
- (void)writeRumConfig:(NSDictionary *)rumConfig;

/// Store traceConfig
/// @param traceConfig Trace configuration items
- (void)writeTraceConfig:(NSDictionary *)traceConfig;

/// Store loggerConfig
/// @param loggerConfig Logger configuration items
- (void)writeLoggerConfig:(NSDictionary *)loggerConfig;

/// Get mobileConfig
/// @param groupIdentifier AppGroups Identifier
/// @return Mobile configuration items
-(NSDictionary *)getMobileConfigWithGroupIdentifier:(NSString *)groupIdentifier;
/// Get rumConfig
/// @param groupIdentifier AppGroups Identifier
/// @return RUM configuration items
- (NSDictionary *)getRumConfigWithGroupIdentifier:(NSString *)groupIdentifier;

/// Get traceConfig
/// @param groupIdentifier AppGroups Identifier
/// @return Trace configuration items
- (NSDictionary *)getTraceConfigWithGroupIdentifier:(NSString *)groupIdentifier;

/// Get loggerConfig
/// @param groupIdentifier AppGroups Identifier
/// @return Logger configuration items
- (NSDictionary *)getLoggerConfigWithGroupIdentifier:(NSString *)groupIdentifier;

/// Add RUM event for corresponding groupIdentifier
/// @param eventType Event type
/// @param tags Event tags
/// @param fields Event metrics
/// @param tm Timestamp
/// @param groupIdentifier AppGroups Identifier
/// @return Whether write was successful
- (BOOL)writeRumEventType:(NSString *)eventType tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm groupIdentifier:(NSString *)groupIdentifier;

/// Add LOGGER event for corresponding groupIdentifier
/// @param status Event type
/// @param content Logger content
/// @param tags Event tags
/// @param fields Event metrics
/// @param tm Timestamp
/// @param groupIdentifier AppGroups Identifier
/// @return Whether write was successful
- (BOOL)writeLoggerEvent:(NSString *)status content:(NSString *)content tags:(NSDictionary *)tags fields:(nullable NSDictionary *)fields tm:(long long)tm groupIdentifier:(NSString *)groupIdentifier;

/// Read all cached events for corresponding groupIdentifier
/// @param groupIdentifier AppGroups Identifier
/// @return All events cached for current groupIdentifier
- (NSArray *)readAllEventsWithGroupIdentifier:(NSString *)groupIdentifier;

/// Delete all cached events for corresponding groupIdentifier
/// @param groupIdentifier AppGroups Identifier
/// @return Whether deletion was successful
- (BOOL)deleteEventsWithGroupIdentifier:(NSString *)groupIdentifier;
@end

NS_ASSUME_NONNULL_END
