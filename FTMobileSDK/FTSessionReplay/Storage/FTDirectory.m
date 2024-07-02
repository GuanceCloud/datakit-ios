//
//  FTDirectory.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDirectory.h"
#import "FTFile.h"
@interface FTDirectory()
@property (nonatomic, strong) NSURL *url;

@end
@implementation FTDirectory
-(instancetype)initWithSubdirectoryPath:(NSString *)path{
    return [[self cache] createSubdirectoryWithPath:path];
}
-(instancetype)initWithUrl:(NSURL *)url{
    self = [super init];
    if(self){
        _url = url;
    }
    return self;
}
//TODO: error 处理
- (FTDirectory *)createSubdirectoryWithPath:(NSString *)path{
    NSURL *subdirectoryURL = [self.url URLByAppendingPathComponent:path isDirectory:YES];
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:subdirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
    if(success){
        return [[FTDirectory alloc] initWithUrl:subdirectoryURL];
    }
    return nil;
}
- (NSDate *)modifiedAt{
    NSError *error;
    NSDate *date = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.url.path error:&error] fileCreationDate];
    return date;
}
- (FTFile *)createFile:(NSString *)fileName{
    NSURL *fileURL = [self.url URLByAppendingPathComponent:fileName isDirectory:NO];
    
   BOOL result = [[NSFileManager defaultManager] createFileAtPath:fileURL.path contents:nil attributes:nil];
    if(result == YES){
        return [[FTFile alloc]initWithUrl:fileURL];
    }
    return nil;
}
- (BOOL)hasFileWithName:(NSString *)fileName{
    NSURL *fileUrl = [self.url URLByAppendingPathComponent:fileName isDirectory:NO];
    return [[NSFileManager defaultManager] fileExistsAtPath:fileUrl.path];
}
- (FTFile *)fileWithName:(NSString *)fileName{
    if([self hasFileWithName:fileName]){
        NSURL *fileUrl = [self.url URLByAppendingPathComponent:fileName isDirectory:NO];
        return [[FTFile alloc]initWithUrl:fileUrl];
    }
    return nil;
}
- (NSArray<FTFile*>*)files{
    NSMutableArray *array = [NSMutableArray new];
    NSError *error;
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.url includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLCanonicalPathKey] options:0 error:&error];
    if(urls && urls.count>0){
        [urls enumerateObjectsUsingBlock:^(NSURL * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [array addObject:[[FTFile alloc]initWithUrl:obj]];
        }];
    }
    return array;
}
- (void)deleteAllFiles{
    FTDirectory *temporaryDirectory = [[FTDirectory alloc]initWithSubdirectoryPath:[[NSUUID UUID] UUIDString]];
    NSError *error;
    [[NSFileManager defaultManager] replaceItemAtURL:self.url withItemAtURL:temporaryDirectory.url backupItemName:nil options:0 resultingItemURL:nil error:&error];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:temporaryDirectory.url.path]){
        [[NSFileManager defaultManager] removeItemAtURL:temporaryDirectory.url error:&error];
    }
}
- (void)moveAllFilesToDestinationDirectory:(FTDirectory *)directory{
    [self retry:3 delay:0.001 block:^(NSError **error) {
        [[self files] enumerateObjectsUsingBlock:^(FTFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSURL *destinationFileURL = [directory.url URLByAppendingPathComponent:obj.name];
            [self retry:3 delay:0.0001 block:^(NSError **error) {
                NSError *lastCriticalError;
                [[NSFileManager defaultManager] moveItemAtURL:obj.url toURL:destinationFileURL error:&lastCriticalError];
                *error = lastCriticalError;
            }];
        }];
    }];
}
- (void)retry:(NSUInteger)times delay:(NSTimeInterval)delay block:(void(^)(NSError **error))block{
    for (int i=0; i<times; i++) {
        __autoreleasing NSError *error;
        block(&error);
        if(error){
            [NSThread sleepForTimeInterval:delay];
        }else{
            return;
        }
    }
}
- (instancetype)cache{
    NSURL *cachesDirectoryURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    return [self initWithUrl:cachesDirectoryURL];
}
@end
