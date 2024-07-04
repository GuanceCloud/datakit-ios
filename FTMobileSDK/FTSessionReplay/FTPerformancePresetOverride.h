//
//  FTPerformancePresetOverride.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/4.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTPerformancePresetOverride : NSObject
@property (nonatomic, assign) long long maxFileSize;
@property (nonatomic, assign) long long maxObjectSize;

@property (nonatomic, assign) NSTimeInterval maxFileAgeForWrite;
@property (nonatomic, assign) NSTimeInterval minFileAgeForRead;


@property (nonatomic, assign) NSTimeInterval initialUploadDelay;
@property (nonatomic, assign) NSTimeInterval minUploadDelay;
@property (nonatomic, assign) NSTimeInterval maxUploadDelay;
@property (nonatomic, assign) double uploadDelayChangeRate;
-(instancetype)initWithMeanFileAge:(NSTimeInterval)meanFileAge minUploadDelay:(NSTimeInterval)minUploadDelay;
@end

NS_ASSUME_NONNULL_END
