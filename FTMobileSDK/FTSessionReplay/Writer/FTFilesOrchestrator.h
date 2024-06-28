//
//  FTFilesOrchestrator.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTFile,FTDirectory;
@protocol FTStoragePerformancePreset,FTWritableFile,FTReadableFile;
@protocol FTFilesOrchestratorType <NSObject>

@property (nonatomic, strong) id<FTStoragePerformancePreset> performance;
@property (nonatomic, assign) BOOL ignoreFilesAgeWhenReading;
- (id<FTWritableFile>)getWritableFile:(long long)writeSize;
- (NSArray<FTFile *>*)getReadableFiles:(NSSet *)excludedFileNames limit:(int)limit;
- (void)deleteReadableFile:(id<FTReadableFile>)readableFile;
@end

@interface FTFilesOrchestrator : NSObject<FTFilesOrchestratorType>
@property (nonatomic, strong) id<FTStoragePerformancePreset> performance;
@property (nonatomic, assign) BOOL ignoreFilesAgeWhenReading;

-(instancetype)initWithDirectory:(FTDirectory *)directory performance:(id <FTStoragePerformancePreset>)performance;


@end

NS_ASSUME_NONNULL_END
