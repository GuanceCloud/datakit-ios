//
//  FTRUMActionScope.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMScope.h"

NS_ASSUME_NONNULL_BEGIN
typedef void(^FTHandler)(void);

@interface FTRUMActionScope : FTRUMScope

@property (nonatomic, copy) FTHandler handler;
-(void)end;
@end

NS_ASSUME_NONNULL_END
