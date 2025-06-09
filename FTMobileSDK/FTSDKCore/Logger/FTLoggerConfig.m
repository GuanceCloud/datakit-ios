//
//  FTLoggerConfig.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTLoggerConfig.h"
#import "FTConstants.h"
#import "FTJSONUtil.h"
@implementation FTLoggerConfig
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
    options.samplerate = self.samplerate;
    options.enableLinkRumData = self.enableLinkRumData;
    options.enableCustomLog = self.enableCustomLog;
    options.logLevelFilter = self.logLevelFilter;
    options.discardType = self.discardType;
    options.globalContext = self.globalContext;
    options.printCustomLogToConsole = self.printCustomLogToConsole;
    options.logCacheLimitCount = self.logCacheLimitCount;
    return options;
}
-(instancetype)initWithDictionary:(NSDictionary *)dict{
    if(dict){
        if (self = [super init]) {
            _samplerate = [dict[@"samplerate"] intValue];
            _enableLinkRumData = [dict[@"enableLinkRumData"] boolValue];
            _enableCustomLog = [dict[@"enableCustomLog"] boolValue];
            _logLevelFilter = dict[@"logLevelFilter"];
            _discardType = (FTLogCacheDiscard)[dict[@"discardType"] intValue];
            _globalContext = dict[@"globalContext"];
            _printCustomLogToConsole = [dict[@"printCustomLogToConsole"] boolValue];
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
    [dict setValue:@(self.samplerate) forKey:@"samplerate"];
    [dict setValue:@(self.enableLinkRumData) forKey:@"enableLinkRumData"];
    [dict setValue:@(self.enableCustomLog) forKey:@"enableCustomLog"];
    [dict setValue:self.logLevelFilter forKey:@"logLevelFilter"];
    [dict setValue:@(self.discardType) forKey:@"discardType"];
    [dict setValue:self.globalContext forKey:@"globalContext"];
    [dict setValue:@(self.logCacheLimitCount) forKey:@"logCacheLimitCount"];
    [dict setValue:@(self.printCustomLogToConsole) forKey:@"printCustomLogToConsole"];
    return dict;
}
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict{
    if (!dict || dict.count == 0) {
        return;
    }
    NSNumber *sampleRate = dict[FT_R_LOG_SAMPLERATE];
    NSString *logLevelFilters = dict[FT_R_LOG_LEVEL_FILTERS];
    NSNumber *enableCustomLog = dict[FT_R_LOG_ENABLE_CUSTOM_LOG];
    if (sampleRate != nil) {
        self.samplerate = [sampleRate doubleValue] * 100;
    }
    if (enableCustomLog != nil) {
        self.enableCustomLog = [enableCustomLog boolValue];
    }
    if (logLevelFilters && logLevelFilters.length > 0) {
        NSArray *filters = [FTJSONUtil arrayWithJsonString:logLevelFilters];
        if (filters.count>0) {
            self.logLevelFilter = filters;
        }
    }
}
-(NSString *)debugDescription{
    return [NSString stringWithFormat:@"%@",[self convertToDictionary]];
}
@end
