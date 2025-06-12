//
//  FTSessionReplayConfig+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/9/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayConfig.h"
#import "FTSRWireframesBuilder.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTSessionReplayConfig ()
@property (nonatomic, strong) NSArray<id <FTSRWireframesRecorder>>*additionalNodeRecorders;
-(void)mergeWithRemoteConfigDict:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
