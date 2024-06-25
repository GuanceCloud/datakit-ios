//
//  FTPerformancePreset.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTPerformancePreset.h"

@implementation FTPerformancePreset
-(instancetype)init{
    return [self initWithMeanFileAge:10 minUploadDelay:2];
}
-(instancetype)initWithMeanFileAge:(NSTimeInterval)meanFileAge minUploadDelay:(NSTimeInterval)minUploadDelay{
    self = [super init];
    if(self){
        _maxFileSize = 4*1024*1024;//4MB
        _maxDirectorySize = 512*1024*1024;//4MB
        _maxFileAgeForWrite = meanFileAge * 0.95;
        _minFileAgeForRead = meanFileAge * 1.05;
        _maxFileAgeForRead = 18 * 60 * 60; // 18 hours
        _maxObjectsInFile = 500;
        _maxObjectSize = 512*1024; //512KB
        
        _initialUploadDelay = minUploadDelay + 5;
        _minUploadDelay = minUploadDelay;
        _maxUploadDelay = minUploadDelay * 10;
        _uploadDelayChangeRate = 0.1;
    }
    return self;
}
@end
