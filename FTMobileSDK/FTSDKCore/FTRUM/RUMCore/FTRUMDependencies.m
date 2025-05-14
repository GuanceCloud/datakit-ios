//
//  FTRUMDependencies.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/10.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTRUMDependencies.h"
#import "FTConstants.h"

@implementation FTRUMDependencies

- (NSDictionary *)sampleFieldsDict{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
        FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE:@(self.sessionOnErrorSampleRate),
        FT_RUM_SESSION_SAMPLE_RATE:@(self.sampleRate)
    }];
    [dict setValue:self.sessionReplaySampleRate forKey:FT_RUM_SESSION_REPLAY_SAMPLE_RATE];
    [dict setValue:self.sessionReplayOnErrorSampleRate forKey:FT_RUM_SESSION_REPLAY_ON_ERROR_SAMPLE_RATE];
    return dict;
}
@end
