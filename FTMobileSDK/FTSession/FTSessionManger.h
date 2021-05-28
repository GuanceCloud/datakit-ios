//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
#import "FTRUMSessionProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTSessionManger : FTRUMHandler<FTRUMSessionErrorDelegate,FTRUMSessionActionDelegate,FTRUMSessionResourceDelegate,FTRUMWebViewJSBridgeDataDelegate>

@end

NS_ASSUME_NONNULL_END
