//
//  FTRUMActionScope.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMScope.h"
@class  FTRUMViewScope;
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTActionEventSent)(void);

@interface FTRUMActionScope : FTRUMScope
@property (nonatomic, strong,readonly) FTRUMCommand *command;

@property (nonatomic, copy) FTActionEventSent handler;

-(instancetype)initWithCommand:(FTRUMCommand *)command parent:(FTRUMViewScope *)parent;
-(void)writeActionData;
@end

NS_ASSUME_NONNULL_END
