//
//  FTSessionManger.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/21.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMScope.h"
#import "FTRUMSessionProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTSessionManger : FTRUMScope<FTRUMSessionErrorDelegate,FTRUMSessionActionDelegate,FTRUMSessionResourceDelegate>

@end

NS_ASSUME_NONNULL_END
