//
//  FTDataFilterPullRequest.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTDataFilterPullRequest.h"
#import "FTNetworkInfoManager.h"

@implementation FTDataFilterPullRequest

- (NSString *)httpMethod {
    return @"GET";
}

- (NSString *)path {
    return @"/v1/datakit/pull";
}

- (NSURL *)absoluteURL {
    FTNetworkInfoManager *info = [FTNetworkInfoManager sharedInstance];
    NSString *urlString = nil;
    switch (info.configState) {
        case FTNetworkConfigStateDatakitMode:
            urlString = [NSString stringWithFormat:@"%@%@?filters=true", info.datakitUrl, self.path];
            break;
        case FTNetworkConfigStateDatawayMode:
            urlString = [NSString stringWithFormat:@"%@%@?token=%@&to_headless=true&filters=true", info.datawayUrl, self.path, info.clientToken];
            break;
        default:
            break;
    }
    return urlString.length > 0 ? [NSURL URLWithString:urlString] : nil;
}

- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest {
    [self addHTTPHeaderFields:mutableRequest packageId:nil];
    mutableRequest.HTTPMethod = self.httpMethod;
    return mutableRequest;
}

@end
