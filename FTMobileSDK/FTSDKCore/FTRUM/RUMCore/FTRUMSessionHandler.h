//
//  FTRUMsessionHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
@class FTRumConfig,FTRUMMonitor;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMSessionHandler : FTRUMHandler

-(instancetype)initWithModel:(FTRUMDataModel *)model sampleRate:(int )sampleRate monitor:(FTRUMMonitor *)monitor writer:(id<FTRUMDataWriteProtocol>)writer;
-(instancetype)initWithExpiredSession:(FTRUMSessionHandler *)expiredSession time:(NSDate *)time;

-(nullable NSString *)getCurrentViewID;
-(NSDictionary *)getCurrentSessionInfo;
@end

NS_ASSUME_NONNULL_END
