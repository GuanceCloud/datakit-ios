//
//  FTRUMactionHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
@class  FTRUMViewHandler;
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTActionEventSent)(void);

@interface FTRUMActionHandler : FTRUMHandler
@property (nonatomic, strong,readonly) FTRUMDataModel *model;

@property (nonatomic, copy) FTActionEventSent handler;

-(instancetype)initWithModel:(FTRUMDataModel *)model;
-(void)writeActionData:(NSDate *)endDate;
@end

NS_ASSUME_NONNULL_END
