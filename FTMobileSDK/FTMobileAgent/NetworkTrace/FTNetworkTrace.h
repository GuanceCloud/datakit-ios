//
//  FTNetworkTrace.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/3/17.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTNetworkTrace : NSObject
-(instancetype)initWithType:(FTNetworkTraceType)type;

- (NSDictionary *)networkTrackHeaderWithSampled:(BOOL)sampled url:(NSURL *)url;
@end

NS_ASSUME_NONNULL_END
