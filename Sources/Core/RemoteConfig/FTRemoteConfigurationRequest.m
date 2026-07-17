//
//  FTRemoteConfigurationRequest.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/5.
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

#import "FTRemoteConfigurationRequest.h"
#import "FTNetworkInfoManager.h"
@implementation FTRemoteConfigurationRequest
-(NSString *)httpMethod{
    return @"GET";
}
-(NSString *)path{
    return @"/v1/env_variable";
}
-(NSURL *)absoluteURL{
    NSURL *url = [super absoluteURL];
    NSString *query = [NSString stringWithFormat:@"app_id=%@",[FTNetworkInfoManager sharedInstance].appId];
    return [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:url.query ? @"&%@" : @"?%@", query]];
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    [self addHTTPHeaderFields:mutableRequest packageId:nil];
    return mutableRequest;
}
@end
