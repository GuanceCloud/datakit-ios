//
//  FTSessionReplayPrivacyOverrides+Extension.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/11.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayPrivacyOverrides.h"

NS_ASSUME_NONNULL_BEGIN
typedef FTSessionReplayPrivacyOverrides PrivacyOverrides;

@interface FTSessionReplayPrivacyOverrides ()
@property (nonatomic, strong, nullable) NSNumber *nImagePrivacy;
@property (nonatomic, strong, nullable) NSNumber *nTouchPrivacy;
@property (nonatomic, strong, nullable) NSNumber *nTextAndInputPrivacy;
+ (PrivacyOverrides *)mergeChild:(PrivacyOverrides *)child parent:(PrivacyOverrides *)parent;
@end

NS_ASSUME_NONNULL_END
