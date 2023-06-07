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
@property (nonatomic, strong, readonly) FTRUMContext *context;
@property (nonatomic, copy) FTActionEventSent handler;

-(instancetype)initWithModel:(FTRUMActionModel *)model context:(FTRUMContext *)context;
-(void)writeActionData:(NSDate *)endDate;
@end

NS_ASSUME_NONNULL_END
