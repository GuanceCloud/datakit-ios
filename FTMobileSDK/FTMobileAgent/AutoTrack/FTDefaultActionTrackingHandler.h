//
//  FTDefaultActionTrackingHandler.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/8/6.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTActionTrackingHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTDefaultActionTrackingHandler : NSObject<FTUITouchRUMActionsHandler,FTUIPressRUMActionsHandler>

@end

#if TARGET_OS_IOS
@interface FTDefaultSwiftUIActionTrackingHandler : NSObject<FTSwiftUIRUMActionsHandler>

@end
#endif

NS_ASSUME_NONNULL_END
