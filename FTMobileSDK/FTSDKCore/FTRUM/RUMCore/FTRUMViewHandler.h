//
//  FTRUMViewHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
NS_ASSUME_NONNULL_BEGIN
@class FTRUMMonitor;
@interface FTRUMViewHandler : FTRUMHandler
@property (nonatomic, strong,readonly) FTRUMContext *context;

-(instancetype)initWithModel:(FTRUMViewModel *)model context:(FTRUMContext *)context monitor:(FTRUMMonitor *)monitor;
@end

NS_ASSUME_NONNULL_END
