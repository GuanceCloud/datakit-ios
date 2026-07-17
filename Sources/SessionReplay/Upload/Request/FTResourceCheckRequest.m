//
//  FTResourceCheckRequest.m
//  SessionReplay
//
//  Created by hulilei on 2025/10/29.
//
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

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

#endif
