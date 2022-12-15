//
//  FTMobileConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTMobileConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTLoggerConfig ()
-(instancetype)initWithDictionary:(NSDictionary *)dict;
-(NSDictionary *)convertToDictionary;
@end

@interface FTRumConfig ()
-(instancetype)initWithDictionary:(NSDictionary *)dict;
-(NSDictionary *)convertToDictionary;
@end

@interface FTTraceConfig ()
-(instancetype)initWithDictionary:(NSDictionary *)dict;
-(NSDictionary *)convertToDictionary;
@end
NS_ASSUME_NONNULL_END
