//
//  FTRUMContext.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/12/22.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRUMContext.h"
#import "FTConstants.h"
#import "FTBaseInfoHandler.h"
#import "NSDate+FTUtil.h"

NS_ASSUME_NONNULL_BEGIN
@interface FTRUMContext ()
@property (nonatomic, strong) FTRUMSessionState *sessionState;
@end
@implementation FTRUMContext
- (instancetype)initWithSampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate{
    self = [super init];
    if (self) {
        self.sessionState = [[FTRUMSessionState alloc] init];
        self.sessionState.sampleRate = sampleRate;
        self.sessionState.sessionOnErrorSampleRate = sessionOnErrorSampleRate;
    }
    return self;
   
}

- (instancetype)copyWithZone:(NSZone *)zone {
    FTRUMContext *context = [[[self class] allocWithZone:zone] init];
    context.action_id = self.action_id;
    context.action_name = self.action_name;
    context.view_id = self.view_id;
    context.view_referrer = self.view_referrer;
    context.view_name = self.view_name;
    context.sessionState = [self.sessionState copy];
    return context;
}
-(NSDictionary *)getGlobalSessionViewTags{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict addEntriesFromDictionary:[self.sessionState sessionTags]];
    [dict setValue:self.view_id forKey:FT_KEY_VIEW_ID];
    if(self.view_referrer.length>0){
        [dict setValue:self.view_referrer forKey:FT_KEY_VIEW_REFERRER];
    }
    [dict setValue:self.view_name forKey:FT_KEY_VIEW_NAME];
    return dict;
}
-(NSDictionary *)getGlobalSessionViewActionTags{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self getGlobalSessionViewTags]];
    [dict setValue:self.action_id forKey:FT_KEY_ACTION_ID];
    [dict setValue:self.action_name forKey:FT_KEY_ACTION_NAME];
    return dict;
}
-(NSDictionary *)getGlobalSessionTags{
    return [self.sessionState sessionTags];
}
@end

@implementation FTRUMSessionState
-(instancetype)init{
    self = [super init];
    if (self) {
        self.session_id = [FTBaseInfoHandler randomUUID];
        self.session_type = @"user";
    }
    return self;
}
-(nullable instancetype)initWithDict:(NSDictionary *)dict{
    if (!dict) {
        return nil;
    }
    self = [super init];
    if (self) {
        self.session_id = dict[FT_RUM_KEY_SESSION_ID];
        self.session_type = dict[FT_RUM_KEY_SESSION_TYPE];
        self.sampled_for_error_session = [dict[FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION] boolValue];
        self.session_error_timestamp = [dict[FT_SESSION_ERROR_TIMESTAMP] longLongValue];
        self.sampleRate = [dict[FT_RUM_SESSION_SAMPLE_RATE] floatValue];
        self.sessionOnErrorSampleRate = [dict[FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE] floatValue];
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    FTRUMSessionState *sessionState = [[[self class] allocWithZone:zone] init];
    sessionState.session_id = self.session_id;
    sessionState.session_type = self.session_type;
    sessionState.sampleRate = self.sampleRate;
    sessionState.sessionOnErrorSampleRate = self.sessionOnErrorSampleRate;
    sessionState.sampled_for_error_session = self.sampled_for_error_session;
    sessionState.session_error_timestamp = self.session_error_timestamp;
    return sessionState;
}
- (NSDictionary *)sessionTags{
    NSMutableDictionary *tags = [NSMutableDictionary new];
    [tags setValue:self.session_id forKey:FT_RUM_KEY_SESSION_ID];
    [tags setValue:self.session_type forKey:FT_RUM_KEY_SESSION_TYPE];
    return [tags copy];
}
- (NSDictionary *)sessionFields{
    NSMutableDictionary *fields = [NSMutableDictionary new];
    [fields setValue:@(self.sampleRate) forKey:FT_RUM_SESSION_SAMPLE_RATE];
    [fields setValue:@(self.sessionOnErrorSampleRate) forKey:FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE];
    if (self.session_error_timestamp > 0) {
        [fields setValue:@(self.session_error_timestamp) forKey:FT_SESSION_ERROR_TIMESTAMP];
    }
    [fields setValue:@(self.sampled_for_error_session) forKey:FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION];
    return [fields copy];
}
-(BOOL)isEqual:(id)object{
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:FTRUMSessionState.class]) {
        return NO;
    }
    FTRUMSessionState *state = (FTRUMSessionState *)object;
    BOOL equalSessionId = [self.session_id isEqualToString:state.session_id];
    BOOL equalSessionType = [self.session_type isEqualToString:state.session_type];
    return equalSessionId && equalSessionType && self.sampleRate == state.sampleRate && self.sessionOnErrorSampleRate == state.sessionOnErrorSampleRate && self.sampled_for_error_session == state.sampled_for_error_session && self.session_error_timestamp == state.session_error_timestamp;
}
- (NSDictionary *)toDictionary{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setValue:self.session_id forKey:FT_RUM_KEY_SESSION_ID];
    [dict setValue:self.session_type forKey:FT_RUM_KEY_SESSION_TYPE];
    [dict setValue:@(self.sampled_for_error_session) forKey:FT_RUM_KEY_SAMPLED_FOR_ERROR_SESSION];
    [dict setValue:@(self.session_error_timestamp) forKey:FT_SESSION_ERROR_TIMESTAMP];
    [dict setValue:@(self.sampleRate) forKey:FT_RUM_SESSION_SAMPLE_RATE];
    [dict setValue:@(self.sessionOnErrorSampleRate) forKey:FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE];
    return dict;
}
@end
NS_ASSUME_NONNULL_END
