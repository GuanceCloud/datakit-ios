//
//  FTRUMSourceScope.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMScope.h"
@class FTRUMViewScope;
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTResourceEventSent)(void);
typedef void(^FTErrorEventSent)(void);

@interface FTRUMResourceScope : FTRUMScope
@property (nonatomic, copy,readonly) NSString *identifier;

@property (nonatomic, copy) FTResourceEventSent resourceHandler;
@property (nonatomic, copy) FTErrorEventSent errorHandler;
-(instancetype)initWithCommand:(FTRUMResourceCommand *)command parent:(FTRUMViewScope *)parent;
@end

NS_ASSUME_NONNULL_END
