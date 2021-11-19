//
//  FTRUMsessionHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
@class FTRumConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMSessionHandler : FTRUMHandler

-(instancetype)initWithModel:(FTRUMDataModel *)model rumConfig:(FTRumConfig *)rumConfig;
-(void)refreshWithDate:(NSDate *)date;
-(NSString *)getCurrentViewID;
-(NSDictionary *)getCurrentSessionInfo;
@end

NS_ASSUME_NONNULL_END
