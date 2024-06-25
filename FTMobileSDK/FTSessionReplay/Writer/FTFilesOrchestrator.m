//
//  FTFilesOrchestrator.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFilesOrchestrator.h"
#import "FTFile.h"
#import "FTPerformancePreset.h"
#import "FTLog+Private.h"
#import "FTDirectory.h"
@interface FTFilesOrchestrator()
@property (nonatomic, copy) NSString *lastWritableFileName;
@property (nonatomic, assign) int lastWritableFileObjectsCount;
@property (nonatomic, assign) long long lastWritableFileApproximatedSize;
@property (nonatomic, strong) NSDate *lastWritableFileLastWriteDate;
@property (nonatomic, strong) FTDirectory *directory;
@end
@implementation FTFilesOrchestrator
-(instancetype)initWithDirectory:(FTDirectory *)directory performance:(id <FTStoragePerformancePreset>)performance{
    self = [super init];
    if(self){
        _directory = directory;
        _performance = performance;
    }
    return self;
}
- (id<FTWritableFile>)getWritableFile:(long long)writeSize{
    if(![self validate:writeSize])
        return nil;
    id<FTWritableFile> lastWritableFile = [self reuseLastWritableFileIfPossible:writeSize];
    if(lastWritableFile!=nil){
        self.lastWritableFileObjectsCount += 1;
        self.lastWritableFileApproximatedSize += writeSize;
        self.lastWritableFileLastWriteDate = [NSDate date];
        return lastWritableFile;
    }else{
        return [self createNewWritableFile:writeSize];
    }
}
- (BOOL)validate:(long long)writeSize{
    if(writeSize<=self.performance.maxObjectSize){
        return YES;
    }else{
        FTInnerLogWarning(@"data exceeds the maximum size of %lld bytes.",self.performance.maxObjectSize);
        return NO;
    }
}
- (id<FTWritableFile>)createNewWritableFile:(long long)writeSize{
    [self purgeFilesDirectoryIfNeeded];
    NSTimeInterval current = [[NSDate date] timeIntervalSinceReferenceDate];
    NSString *name = [NSString stringWithFormat:@"%f",round(current*1000)];
    FTFile *file = [self.directory createFile:name];
    if(file){
        self.lastWritableFileName = name;
        self.lastWritableFileObjectsCount = 1;
        self.lastWritableFileApproximatedSize = writeSize;
        self.lastWritableFileLastWriteDate = [NSDate date];
    }
    return file;
}
- (void)purgeFilesDirectoryIfNeeded{
    NSMutableArray<FTFile *> *filesSortedByCreationDate = [NSMutableArray arrayWithArray: [[self.directory files] sortedArrayUsingComparator:^NSComparisonResult(FTFile * obj1, FTFile * obj2) {
        return obj1.fileCreationDate > obj2.fileCreationDate;
    }]];
    
    __block long long accumulatedFilesSize;
    [filesSortedByCreationDate enumerateObjectsUsingBlock:^(FTFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        accumulatedFilesSize += [obj size];
    }];
    
    if (accumulatedFilesSize > self.performance.maxDirectorySize) {
        long long sizeToFree = accumulatedFilesSize - self.performance.maxDirectorySize;
        long long sizeFreed = 0;
        while (sizeFreed<sizeToFree && !(filesSortedByCreationDate.count==0)) {
            FTFile *file = [filesSortedByCreationDate lastObject];
            [filesSortedByCreationDate removeLastObject];
            [file deleteFile];
            sizeFreed += file.size;
        }
    }
}
- (id<FTWritableFile>)reuseLastWritableFileIfPossible:(long long)writeSize{
    if(self.lastWritableFileName){
        if(![self.directory hasFileWithName:self.lastWritableFileName]){
            return nil;
        }
        FTFile *file = [self.directory fileWithName:self.lastWritableFileName];
        NSDate *lastFileCreationDate = file.fileCreationDate;
        NSTimeInterval lastFileAge = [[NSDate date] timeIntervalSinceDate:lastFileCreationDate];
        BOOL fileIsRecentEnough = lastFileAge <= self.performance.maxFileAgeForWrite;
        BOOL fileHasRoomForMore = [file size] + writeSize <= self.performance.maxFileSize;
        BOOL fileCanBeUsedMoreTimes = self.lastWritableFileObjectsCount + 1 <= self.performance.maxObjectsInFile;
        if(fileIsRecentEnough && fileHasRoomForMore && fileCanBeUsedMoreTimes){
            return file;
        }
    }
    return nil;
}
- (NSArray<FTFile *>*)getReadableFiles:(NSSet *)excludedFileNames limit:(int)limit{
    NSMutableArray<FTFile *> *deleteObsolete = [NSMutableArray new];
    [[self.directory files] enumerateObjectsUsingBlock:^(FTFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        FTFile *file = [self deleteFileIfItsObsolete:obj];
        if(file){
            [deleteObsolete addObject:file];
        }
    }];
    NSArray *filesFromOldest = [deleteObsolete sortedArrayUsingComparator:^NSComparisonResult(FTFile * obj1, FTFile * obj2) {
        return obj1.fileCreationDate < obj2.fileCreationDate;
    }];
    NSMutableArray *readableArray = [NSMutableArray new];
    [filesFromOldest enumerateObjectsUsingBlock:^(FTFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(![excludedFileNames containsObject:obj.name]){
            [readableArray addObject:obj];
        }
    }];
    if(self.ignoreFilesAgeWhenReading){
        NSInteger length = limit > readableArray.count?readableArray.count:limit;
        return [readableArray subarrayWithRange:NSMakeRange(0, length)];
    }
    __block NSUInteger index = 0;
    __weak typeof(self) weakSelf = self;
    [readableArray enumerateObjectsUsingBlock:^(FTFile * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSTimeInterval fileAge = [[NSDate date] timeIntervalSinceDate:obj.fileCreationDate];
        if(fileAge < weakSelf.performance.minFileAgeForRead){
            index = idx;
            *stop = YES;
        }
    }];
    NSInteger length = limit > index+1?index+1:limit;
    return [readableArray subarrayWithRange:NSMakeRange(0, length)];
}
- (FTFile *)deleteFileIfItsObsolete:(FTFile *)file{
    NSTimeInterval fileAge = [[NSDate date] timeIntervalSinceDate:file.fileCreationDate];
    if(fileAge > self.performance.maxFileAgeForRead){
        [file deleteFile];
        return nil;
    }
    return file;
}
@end
