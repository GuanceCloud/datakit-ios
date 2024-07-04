//
//  FTResourcesFeature.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTResourcesFeature.h"
#import "FTResourceRequest.h"
#import "FTPerformancePresetOverride.h"
#import "FTTLV.h"
@implementation FTResourcesFeature
-(instancetype)init{
    self = [super init];
    if(self){
        _name = @"session-replay-resources";
        _requestBuilder = [[FTResourceRequest alloc]init];
        FTPerformancePresetOverride *performanceOverride = [[FTPerformancePresetOverride alloc]init];
        performanceOverride.maxObjectSize = FT_MAX_DATA_LENGTH;
        performanceOverride.maxFileSize = FT_MAX_DATA_LENGTH;
        _performanceOverride = performanceOverride;
    }
    return self;
}
@end
