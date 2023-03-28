//
//  FTLogHook.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/6/15.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^FTFishHookCallBack)(NSString *logStr,long long tm);

@interface FTLogHook : NSObject

+ (void)hookWithBlock:(FTFishHookCallBack)callBack;
@end

NS_ASSUME_NONNULL_END
