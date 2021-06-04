//
//  FTRUMResourceHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
@class FTRUMViewHandler;
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTResourceEventSent)(void);
typedef void(^FTErrorEventSent)(void);

@interface FTRUMResourceHandler : FTRUMHandler
@property (nonatomic, copy,readonly) NSString *identifier;

@property (nonatomic, copy) FTResourceEventSent resourceHandler;
@property (nonatomic, copy) FTErrorEventSent errorHandler;
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model;
@end

NS_ASSUME_NONNULL_END
