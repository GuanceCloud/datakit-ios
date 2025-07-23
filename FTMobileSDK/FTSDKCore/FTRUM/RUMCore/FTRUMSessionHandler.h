//
//  FTRUMsessionHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import "FTRUMDependencies.h"
@class FTRumConfig,FTRUMMonitor;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMSessionHandler : FTRUMHandler
@property (nonatomic, strong) FTRUMDependencies *rumDependencies;

-(instancetype)initWithModel:(FTRUMDataModel *)model dependencies:(FTRUMDependencies *)dependencies;
-(instancetype)initWithExpiredSession:(FTRUMSessionHandler *)expiredSession time:(NSDate *)time;

-(nullable NSString *)getCurrentViewID;
-(NSDictionary *)getCurrentSessionInfo;
@end

NS_ASSUME_NONNULL_END
