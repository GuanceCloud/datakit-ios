//
//  FTRUMContext.h
//
//  Created by hulilei on 2025/12/22.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTErrorDataProtocol.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTDictionaryConvertible;

@interface FTRUMSessionState : NSObject<FTDictionaryConvertible>
// session tags
@property (nonatomic, copy) NSString *session_id;
@property (nonatomic, copy) NSString *session_type;
// session fields
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int sessionOnErrorSampleRate;
@property (nonatomic, assign) long long session_error_timestamp;
@property (nonatomic, assign) BOOL sampled_for_error_session;

- (NSDictionary *)sessionTags;
- (NSDictionary *)sessionFields;

@end

@interface FTRUMContext : NSObject

@property (nonatomic, strong, readonly) FTRUMSessionState *sessionState;

@property (nonatomic, copy, nullable) NSString *view_id;
@property (nonatomic, copy, nullable) NSString *view_name;
@property (nonatomic, copy, nullable) NSString *view_referrer;
@property (nonatomic, copy, nullable) NSString *action_id;
@property (nonatomic, copy, nullable) NSString *action_name;

- (instancetype)initWithSampleRate:(int)sampleRate sessionOnErrorSampleRate:(int)sessionOnErrorSampleRate;

- (instancetype)init NS_UNAVAILABLE;

/// trace, logger get rum correlation data
-(NSDictionary *)getGlobalSessionViewTags;
/// rum internal get related correlation data
-(NSDictionary *)getGlobalSessionViewActionTags;

-(NSDictionary *)getGlobalSessionTags;

@end

NS_ASSUME_NONNULL_END
