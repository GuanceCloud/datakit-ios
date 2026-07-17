//
//  FTUserInfo.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/8/8.
//  Copyright 2022 Shanghai Guance Information Technology Co., Ltd.
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

NS_ASSUME_NONNULL_BEGIN

/// User information
///
/// Reserved fields: userid, user_name, user_email
@interface FTUserInfo : NSObject
/// User ID
@property (nonatomic, copy, readonly) NSString *userId;
/// User name
@property (nonatomic, copy, readonly) NSString *name;
/// User email
@property (nonatomic, copy, readonly) NSString *email;
/// Additional information
@property (nonatomic, copy, readonly) NSDictionary *extra;
/// Whether user information is set
@property (nonatomic, assign, readonly) BOOL isSignIn;

/// Update locally saved user information
/// - Parameters:
///   - Id:  ID
///   - name:  Name
///   - email: Email
///   - extra: Additional information
-(NSDictionary *)updateUser:(NSString *)Id name:(nullable NSString *)name email:(nullable NSString *)email extra:(nullable NSDictionary *)extra;

- (NSDictionary *)userInfoDict;

/// Clear locally saved user information
-(NSDictionary *)clearUser;
@end

NS_ASSUME_NONNULL_END
