//
//  FTDirectory.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDirectory.h"
#import "FTFile.h"
#import "FTLog+Private.h"
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
- (FTDirectory *)createSubdirectoryWithPath:(NSString *)path{
    NSURL *subdirectoryURL = [self.url URLByAppendingPathComponent:path isDirectory:YES];
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:subdirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
    if(success){
        return [[FTDirectory alloc] initWithUrl:subdirectoryURL];
    }
    if(error){
        FTInnerLogError(@"Create directory at %@ fail with error : %@",path,error.localizedDescription);
    }
    return nil;
}
- (NSDate *)modifiedAt{
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.url.path error:&error];
    if(error){
        FTInnerLogError(@"Get file[%@] attributes fail with error : %@",self.url.path,error.localizedDescription);
    }else{
        NSDate *date = [attributes fileCreationDate];
        return date;
    }
    return nil;
}
- (FTFile *)createFile:(NSString *)fileName{
    NSURL *fileURL = [self.url URLByAppendingPathComponent:fileName isDirectory:NO];
    
    BOOL result = [[NSFileManager defaultManager] createFileAtPath:fileURL.path contents:nil attributes:nil];
    if(result == YES){
        return [[FTFile alloc]initWithUrl:fileURL];
    }else{
        FTInnerLogError(@"Create file[%@] attributes fail.",fileURL.path);
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
    [self retry:3 delay:0.001 block:^(NSError **error) {
        NSError *fileError;
        [[NSFileManager defaultManager] replaceItemAtURL:self.url withItemAtURL:temporaryDirectory.url backupItemName:nil options:0 resultingItemURL:nil error:&fileError];
        *error = fileError;
    }];
    if([[NSFileManager defaultManager] fileExistsAtPath:temporaryDirectory.url.path]){
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtURL:temporaryDirectory.url error:&error];
    }
}
- (void)moveAllFilesToDestinationDirectory:(FTDirectory *)directory{
    [[self files] enumerateObjectsUsingBlock:^(FTFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURL *destinationFileURL = [directory.url URLByAppendingPathComponent:obj.name];
        [self retry:3 delay:0.001 block:^(NSError **error) {
            NSError *lastCriticalError = nil;
            [[NSFileManager defaultManager] moveItemAtURL:obj.url toURL:destinationFileURL error:&lastCriticalError];
            if (error != NULL) {
               *error = lastCriticalError;
            }
        }];
    }];
}
- (void)retry:(NSUInteger)times delay:(NSTimeInterval)delay block:(void(^)(NSError **error))block{
    NSError *error;
    int count = 0;
    do {
        count++;
        block(&error);
        if(error){
            [NSThread sleepForTimeInterval:delay];
        }
    } while (error!=nil&&count<times);
}
- (instancetype)cache{
    NSURL *cachesDirectoryURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    return [self initWithUrl:cachesDirectoryURL];
}
@end
