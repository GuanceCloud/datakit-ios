//
//  FTRUMViewScope.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMScope.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMViewScope : FTRUMScope
@property (nonatomic, assign,readonly) BOOL isActiveView;

-(instancetype)initWithModel:(FTRUMCommand *)model;
@end

NS_ASSUME_NONNULL_END
