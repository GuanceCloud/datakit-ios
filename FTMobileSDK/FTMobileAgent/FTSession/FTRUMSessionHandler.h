//
//  FTRUMsessionHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTRUMSessionHandler : FTRUMHandler
-(instancetype)initWithModel:(FTRUMDataModel *)model;

-(void)refreshWithDate:(NSDate *)date;
@end

NS_ASSUME_NONNULL_END
