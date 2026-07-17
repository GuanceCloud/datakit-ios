//
//  FTLoggerConfig.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
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

#import "FTLoggerConfig.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
#import "FTInnerLog.h"
#import "NSDictionary+FTCopyProperties.h"

@implementation FTLoggerConfig
- (int)sampleRate {
    return _samplerate;
}
- (void)setSampleRate:(int)sampleRate {
    _samplerate = sampleRate;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        _discardType = FTDiscard;
        _samplerate = 100;
        _enableLinkRumData = NO;
        _enableCustomLog = NO;
        _logCacheLimitCount = FT_DB_LOG_MAX_COUNT;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTLoggerConfig *options = [[[self class] allocWithZone:zone] init];
    options.sampleRate = self.sampleRate;
    options.enableLinkRumData = self.enableLinkRumData;
    options.enableCustomLog = self.enableCustomLog;
    options.logLevelFilter = [self.logLevelFilter copy];
    options.discardType = self.discardType;
    options.globalContext = [self.globalContext copy];
    options.printCustomLogToConsole = self.printCustomLogToConsole;
    options.logCacheLimitCount = self.logCacheLimitCount;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [self init]) {
            if ([dict ft_hasValidValueForKey:@"samplerate"]) _samplerate = [dict[@"samplerate"] intValue];
            if ([dict ft_hasValidValueForKey:@"sampleRate"]) _samplerate = [dict[@"sampleRate"] intValue];
            if ([dict ft_hasValidValueForKey:@"enableLinkRumData"]) _enableLinkRumData = [dict[@"enableLinkRumData"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableCustomLog"]) _enableCustomLog = [dict[@"enableCustomLog"] boolValue];
            if ([dict ft_hasValidValueForKey:@"logLevelFilter"]) _logLevelFilter = [dict[@"logLevelFilter"] copy];
            if ([dict ft_hasValidValueForKey:@"discardType"]) _discardType = (FTLogCacheDiscard)[dict[@"discardType"] intValue];
            if ([dict ft_hasValidValueForKey:@"globalContext"]) _globalContext = [dict[@"globalContext"] copy];
            if ([dict ft_hasValidValueForKey:@"printCustomLogToConsole"]) _printCustomLogToConsole = [dict[@"printCustomLogToConsole"] boolValue];
            if ([dict ft_hasValidValueForKey:@"logCacheLimitCount"]) self.logCacheLimitCount = [dict[@"logCacheLimitCount"] intValue];
        }
        return self;
    }else{
        return nil;
    }
}
-(void)setLogCacheLimitCount:(int)logCacheLimitCount{
    _logCacheLimitCount = MAX(FT_DB_LOG_MIN_COUNT, logCacheLimitCount);
}
-(NSDictionary *)convertToDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:@(self.sampleRate) forKey:@"sampleRate"];
    [dict setValue:@(self.enableLinkRumData) forKey:@"enableLinkRumData"];
    [dict setValue:@(self.enableCustomLog) forKey:@"enableCustomLog"];
    [dict setValue:self.logLevelFilter forKey:@"logLevelFilter"];
    [dict setValue:@(self.discardType) forKey:@"discardType"];
    [dict setValue:self.globalContext forKey:@"globalContext"];
    [dict setValue:@(self.logCacheLimitCount) forKey:@"logCacheLimitCount"];
    [dict setValue:@(self.printCustomLogToConsole) forKey:@"printCustomLogToConsole"];
    return dict;
}

-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"%@",[self convertToDictionary]];
}
@end
