//
//  FTRumSessionReplay.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef NS_ENUM(NSUInteger,FTSRPrivacy){
    FTSRPrivacyMaskNone,
    FTSRPrivacyMaskOnlyInput,
    FTSRPrivacyMaskAllText,
};
NS_ASSUME_NONNULL_BEGIN
@interface FTRumSessionReplay : NSObject
+ (instancetype)sharedInstance;

- (void)startWithPrivacy:(FTSRPrivacy)privacy;
@end

NS_ASSUME_NONNULL_END
