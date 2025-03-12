//
//  FTSessionReplayPrivacyOverrides.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/11.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSessionReplayConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTSessionReplayPrivacyOverrides : NSObject

@property (nonatomic, assign) FTTouchPrivacyLevel touchPrivacy;

@property (nonatomic, assign) FTTextAndInputPrivacyLevel textAndInputPrivacy;

@property (nonatomic, assign) FTImagePrivacyLevel imagePrivacy;

@property (nonatomic, assign) BOOL hide;
@end

NS_ASSUME_NONNULL_END
