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
    [self addHTTPHeaderFields:mutableRequest packageId:[FTPackageIdGenerator generatePackageId:self.serialNumber count:self.resources.count]];
    
    mutableRequest.HTTPMethod = self.httpMethod;
    
    NSDictionary *params = @{FT_APP_ID:appId,
                             @"files":self.resources
    };
    NSError *jsonError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:&jsonError];
    
    mutableRequest.HTTPBody = jsonData;
    
    return mutableRequest;
}
@end
