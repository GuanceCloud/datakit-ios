//
//  FTFeatureDataStore.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/1.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFeatureDataStore.h"
#import "FTDirectory.h"
#import "FTDataStoreFileReader.h"
#import "FTDataStoreFileWriter.h"
#import "FTFile.h"
#import "FTLog+Private.h"
@interface FTFeatureDataStore()
@property (nonatomic, copy) NSString *feature;
@property (nonatomic, copy) NSString *directoryPath;
@property (nonatomic, strong) FTDirectory *directory;
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@implementation FTFeatureDataStore

-(instancetype)initWithFeature:(NSString *)feature 
                         queue:(dispatch_queue_t)queue
                     directory:(FTDirectory *)directory{
    self = [super init];
    if(self){
        _feature = feature;
        _queue = queue;
        _directory = directory;
        _directoryPath = [NSString stringWithFormat:@"%d/%@",DataStoreDefaultKeyVersion,feature];
    }
    return self;
}
- (void)removeValueForKey:(NSString *)key{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            [strongSelf deleteDataForKey:key];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}

- (void)setValue:(NSData *)value forKey:(NSString *)key version:(FTDataStoreKeyVersion)version { 
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            [strongSelf write:value forKey:key version:version];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}

- (void)valueForKey:(NSString *)key callback:(DataStoreValueResult)callback{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            [strongSelf readDataForKey:key callBack:callback];
        } @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}
- (void)readDataForKey:(NSString *)key callBack:(DataStoreValueResult)callBack{
    FTDirectory *directory = [self.directory createSubdirectoryWithPath:self.directoryPath];
    if([directory hasFileWithName:key]){
        FTFile  *file = [directory fileWithName:key];
        FTDataStoreFileReader *reader = [[FTDataStoreFileReader alloc]initWithFile:file];
        [reader read:callBack];
    }else{
        callBack(nil,nil,-1);
    }
}

- (void)write:(NSData *)data forKey:(NSString *)key version:(FTDataStoreKeyVersion)version{
    FTDirectory *directory = [self.directory createSubdirectoryWithPath:self.directoryPath];
    FTFile *file;
    if([directory hasFileWithName:key]){
        file = [directory fileWithName:key];
    }else{
        file = [directory createFile:key];
    }
    FTDataStoreFileWriter *writer = [[FTDataStoreFileWriter alloc]initWithFile:file];
    [writer write:data version:version];
}
- (void)deleteDataForKey:(NSString *)key{
    FTDirectory *directory = [self.directory createSubdirectoryWithPath:self.directoryPath];
    if([directory hasFileWithName:key]){
        FTFile *file = [directory fileWithName:key];
        [file deleteFile];
    }
}

@end
