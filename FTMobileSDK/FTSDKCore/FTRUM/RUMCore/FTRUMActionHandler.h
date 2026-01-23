//
//  FTRUMactionHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"

@class  FTRUMViewHandler,FTRUMContext;
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTActionEventSent)(void);

@interface FTRUMActionHandler : FTRUMHandler
@property (nonatomic, strong, readonly) FTRUMContext *context;
@property (nonatomic, copy) FTActionEventSent handler;

-(instancetype)initWithModel:(FTRUMActionModel *)model context:(FTRUMContext *)context dependencies:(nonnull FTRUMDependencies *)dependencies;
-(void)writeActionData:(NSDate *)endDate context:(NSDictionary *)context;
@end

NS_ASSUME_NONNULL_END
