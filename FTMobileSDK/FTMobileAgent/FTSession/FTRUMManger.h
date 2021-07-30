//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import "FTRUMSessionProtocol.h"
@class FTRumConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMManger : FTRUMHandler<FTRUMSessionErrorDelegate,FTRUMSessionActionDelegate,FTRUMSessionResourceDelegate,FTRUMWebViewJSBridgeDataDelegate,FTRUMSessionViewDelegate>
@property (nonatomic, strong) FTRumConfig *rumConfig;
-(instancetype)initWithRumConfig:(FTRumConfig *)rumConfig;
-(NSDictionary *)getCurrentSessionInfo;
@end

NS_ASSUME_NONNULL_END
