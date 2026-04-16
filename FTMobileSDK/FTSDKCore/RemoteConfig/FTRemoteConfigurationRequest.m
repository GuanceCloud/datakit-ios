//
//  FTRemoteConfigurationRequest.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/6/5.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
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
    NSString *packageId = [FTPackageIdGenerator generatePackageId:self.serialNumber count:self.events.count];
    [self addHTTPHeaderFields:mutableRequest packageId:packageId];
    return mutableRequest;
}
@end
