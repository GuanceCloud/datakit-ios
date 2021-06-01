//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import "FTRUMSessionProtocol.h"
@class FTMobileConfig;
NS_ASSUME_NONNULL_BEGIN

@interface FTRUMManger : FTRUMHandler<FTRUMSessionErrorDelegate,FTRUMSessionActionDelegate,FTRUMSessionResourceDelegate,FTRUMWebViewJSBridgeDataDelegate>
-(instancetype)initWithConfig:(FTMobileConfig *)config;
@end

NS_ASSUME_NONNULL_END