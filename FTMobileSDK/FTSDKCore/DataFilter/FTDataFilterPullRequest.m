//
//  FTDataFilterPullRequest.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
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
    NSString *packageId = [FTPackageIdGenerator generatePackageId:self.serialNumber count:self.events.count];
    [self addHTTPHeaderFields:mutableRequest packageId:packageId];
    mutableRequest.HTTPMethod = self.httpMethod;
    return mutableRequest;
}

@end
