//
//  FTResourceCheckRequest.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/10/29.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTResourceCheckRequest.h"
#import "FTRequestMultipartFormBody.h"
#import "FTSessionReplayCoreImports.h"
#import "FTCompression.h"
#import "FTSRRecord.h"
@interface FTResourceCheckRequest ()
@property (nonatomic, strong) NSArray<FTEnrichedResource *> *resources;
@property (nonatomic, strong) NSDictionary *parameters;
@end
@implementation FTResourceCheckRequest
-(NSString *)path{
    return @"/v1/check/rum/replay_assets";
}
-(NSString *)contentType{
    return @"application/json";
}
-(NSString *)userAgent{
    return [[super userAgent] stringByAppendingString:@" (Mode=Replay)"];
}
-(void)requestWithEvents:(NSArray *)events parameters:(NSDictionary *)parameters{
    self.resources = events;
    self.parameters = parameters;
}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)mutableRequest{
    NSString *appId = self.parameters[FT_APP_ID];
    if(!appId || !self.resources || self.resources.count == 0){
        return nil;
    }
    [self addHTTPHeaderFields:mutableRequest packageId:nil];
    
    mutableRequest.HTTPMethod = self.httpMethod;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:appId forKey:FT_APP_ID];
    if (self.parameters) {
        [params addEntriesFromDictionary:self.parameters];
    }
    [params setValue:self.resources forKey:@"files"];
    NSError *jsonError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:&jsonError];
    if (jsonError) {
        return nil;
    }
    
    mutableRequest.HTTPBody = jsonData;
    
    return mutableRequest;
}
@end
