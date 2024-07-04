//
//  FTPerformancePresetOverride.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTPerformancePresetOverride.h"

@implementation FTPerformancePresetOverride
-(instancetype)init{
    self = [super init];
    if(self){
        _maxFileSize = -1;
        _maxObjectSize = -1;
        
        _maxFileAgeForWrite = -1;
        _minFileAgeForRead = -1;
        
        _initialUploadDelay = -1;
        _minUploadDelay = -1;
        _maxUploadDelay = -1;
        _uploadDelayChangeRate = -1;
    }
    return self;
}
-(instancetype)initWithMeanFileAge:(NSTimeInterval)meanFileAge minUploadDelay:(NSTimeInterval)minUploadDelay{
    self = [self init];
    _maxFileAgeForWrite = meanFileAge * 0.95;
    _minFileAgeForRead = meanFileAge * 1.05;
    _minUploadDelay = minUploadDelay;
    _maxUploadDelay = minUploadDelay * 10;
    return self;
}
@end
