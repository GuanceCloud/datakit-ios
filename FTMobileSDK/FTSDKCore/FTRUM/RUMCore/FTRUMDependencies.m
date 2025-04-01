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
- (NSDictionary *)sampleDict{
        return @{FT_RUM_SESSION_ON_ERROR_SAMPLE_RATE:@(self.sessionOnErrorSampleRate),
             FT_RUM_SESSION_SAMPLE_RATE:@(self.sampleRate)
    };
}
@end
