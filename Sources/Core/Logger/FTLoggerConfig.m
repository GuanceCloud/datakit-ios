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
#import "FTBaseInfoHandler.h"
#import "NSDictionary+FTCopyProperties.h"

@implementation FTLoggerConfig
- (int)sampleRate {
    return (int)_logSamplingRate;
}
- (void)setSampleRate:(int)sampleRate {
    self.logSamplingRate = (float)sampleRate;
}
- (int)samplerate {
    return (int)_logSamplingRate;
}
- (void)setSamplerate:(int)samplerate {
    self.logSamplingRate = (float)samplerate;
}
- (void)setLogSamplingRate:(float)logSamplingRate {
    if (![FTBaseInfoHandler isValidSamplingRate:logSamplingRate]) {
        FTInnerLogWarning(@"[sampling] Ignore invalid logSamplingRate: %g", logSamplingRate);
        return;
    }
    _logSamplingRate = logSamplingRate;
}
-(instancetype)init{
    self = [super init];
    if (self) {
        _discardType = FTDiscard;
        _logSamplingRate = 100.0f;
        _enableLinkRumData = NO;
        _enableCustomLog = NO;
        _enableWebViewLog = NO;
        _logCacheLimitCount = FT_DB_LOG_MAX_COUNT;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTLoggerConfig *options = [[[self class] allocWithZone:zone] init];
    options->_logSamplingRate = _logSamplingRate;
    options.enableLinkRumData = self.enableLinkRumData;
    options.enableCustomLog = self.enableCustomLog;
    options.enableWebViewLog = self.enableWebViewLog;
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
            if ([dict ft_hasValidValueForKey:@"samplerate"]) self.logSamplingRate = (float)[dict[@"samplerate"] intValue];
            if ([dict ft_hasValidValueForKey:@"sampleRate"]) self.logSamplingRate = (float)[dict[@"sampleRate"] intValue];
            if ([dict ft_hasValidValueForKey:@"logSamplingRate"]) self.logSamplingRate = [dict[@"logSamplingRate"] floatValue];
            if ([dict ft_hasValidValueForKey:@"enableLinkRumData"]) _enableLinkRumData = [dict[@"enableLinkRumData"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableCustomLog"]) _enableCustomLog = [dict[@"enableCustomLog"] boolValue];
            if ([dict ft_hasValidValueForKey:@"enableWebViewLog"]) _enableWebViewLog = [dict[@"enableWebViewLog"] boolValue];
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
    [dict setValue:@((int)_logSamplingRate) forKey:@"sampleRate"];
    [dict setValue:@(_logSamplingRate) forKey:@"logSamplingRate"];
    [dict setValue:@(self.enableLinkRumData) forKey:@"enableLinkRumData"];
    [dict setValue:@(self.enableCustomLog) forKey:@"enableCustomLog"];
    [dict setValue:@(self.enableWebViewLog) forKey:@"enableWebViewLog"];
    [dict setValue:self.logLevelFilter forKey:@"logLevelFilter"];
    [dict setValue:@(self.discardType) forKey:@"discardType"];
    [dict setValue:self.globalContext forKey:@"globalContext"];
    [dict setValue:@(self.logCacheLimitCount) forKey:@"logCacheLimitCount"];
    [dict setValue:@(self.printCustomLogToConsole) forKey:@"printCustomLogToConsole"];
    return dict;
}

-(NSString *)debugDescription{
    NSMutableDictionary *dict = [[self convertToDictionary] mutableCopy];
    [dict setValue:@(self.logSamplingRate) forKey:@"logSamplingRate"];
    return [NSString stringWithFormat:@"%@",dict];
}
@end
