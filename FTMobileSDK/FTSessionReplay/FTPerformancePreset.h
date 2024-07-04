//
//  FTPerformancePreset.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTPerformancePresetOverride;
NS_ASSUME_NONNULL_BEGIN
@protocol FTStoragePerformancePreset <NSObject>
@property (nonatomic, assign) long long maxFileSize;
@property (nonatomic, assign) long long maxDirectorySize;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForWrite;
@property (nonatomic, assign) NSTimeInterval minFileAgeForRead;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForRead;
@property (nonatomic, assign) int maxObjectsInFile;
@property (nonatomic, assign) long long maxObjectSize;
@end

@protocol FTUploadPerformancePreset <NSObject>

@property (nonatomic, assign) NSTimeInterval initialUploadDelay;
@property (nonatomic, assign) NSTimeInterval minUploadDelay;
@property (nonatomic, assign) NSTimeInterval maxUploadDelay;
@property (nonatomic, assign) double uploadDelayChangeRate;

@end
@interface FTPerformancePreset : NSObject<FTStoragePerformancePreset,FTUploadPerformancePreset>
@property (nonatomic, assign) long long maxFileSize;
@property (nonatomic, assign) long long maxDirectorySize;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForWrite;
@property (nonatomic, assign) NSTimeInterval minFileAgeForRead;
@property (nonatomic, assign) NSTimeInterval maxFileAgeForRead;
@property (nonatomic, assign) int maxObjectsInFile;
@property (nonatomic, assign) long long maxObjectSize;

@property (nonatomic, assign) NSTimeInterval initialUploadDelay;
@property (nonatomic, assign) NSTimeInterval minUploadDelay;
@property (nonatomic, assign) NSTimeInterval maxUploadDelay;
@property (nonatomic, assign) double uploadDelayChangeRate;

-(instancetype)initWithMeanFileAge:(NSTimeInterval)meanFileAge minUploadDelay:(NSTimeInterval)minUploadDelay;
- (FTPerformancePreset *)updateWithOverride:(FTPerformancePresetOverride *)overridePreset;
@end

NS_ASSUME_NONNULL_END
