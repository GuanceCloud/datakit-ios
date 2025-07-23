//
//  FTFeatureStorage.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFeatureStorage.h"
#import "FTFilesOrchestrator.h"
#import "FTDirectory.h"
#import "FTPerformancePreset.h"
#import "FTFileWriter.h"
#import "FTDataReader.h"
#import "FTFileReader.h"
#import "FTDataReader.h"
#import "FTLog+Private.h"
#import "FTTmpCacheManager.h"

@interface FTFeatureStorage()
@property (nonatomic, copy) NSString *featureName;
@property (nonatomic, strong) FTFilesOrchestrator *authorizedFilesOrchestrator;
@property (nonatomic, strong, nullable) FTFilesOrchestrator *cacheAuthorizedFilesOrchestrator;

// TODO: Privacy regulations
//@property (nonatomic, strong) FTFilesOrchestrator *unauthorizedFilesOrchestrator;
@property (nonatomic, strong) FTPerformancePreset *performance;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) FTDirectory *directory;
@property (nonatomic, strong) FTDirectory *cacheDirectory;
@property (nonatomic, strong) id<FTCacheWriter> cacheWriter;
@end
@implementation FTFeatureStorage

-(instancetype)initWithFeatureName:(NSString *)featureName 
                             queue:(dispatch_queue_t)queue
                         directory:(FTDirectory *)directory
                    cacheDirectory:(FTDirectory *)cacheDirectory
                       performance:(FTPerformancePreset *)performance{
    self = [super init];
    if(self){
        _featureName = featureName;
        _queue = queue;
        _performance = performance;
        _directory = directory;
        _cacheDirectory = cacheDirectory;
    }
    return self;
}
- (id<FTWriter>)writer{
    FTFileWriter *fileWriter = [[FTFileWriter alloc]initWithOrchestrator:self.authorizedFilesOrchestrator queue:self.queue];
    return fileWriter;
}
- (id<FTCacheWriter>)cacheWriter{
    if (self.cacheAuthorizedFilesOrchestrator) {
        if (!_cacheWriter) {
            FTFileWriter *realFileWriter = [[FTFileWriter alloc]initWithOrchestrator:self.cacheAuthorizedFilesOrchestrator queue:self.queue];
            FTTmpCacheManager *fileWriter = [[FTTmpCacheManager alloc]initWithCacheFileWriter:realFileWriter cacheDirectory:self.cacheDirectory directory:self.directory queue:self.queue];
            _cacheWriter = fileWriter;
        }
        return _cacheWriter;
    }
    return nil;
}
-(FTFilesOrchestrator *)authorizedFilesOrchestrator{
    if(!_authorizedFilesOrchestrator){
        _authorizedFilesOrchestrator = [[FTFilesOrchestrator alloc]initWithDirectory:self.directory performance:self.performance];
    }
    return _authorizedFilesOrchestrator;
}
-(FTFilesOrchestrator *)cacheAuthorizedFilesOrchestrator{
    if (self.cacheDirectory) {
        if(!_cacheAuthorizedFilesOrchestrator){
            _cacheAuthorizedFilesOrchestrator = [[FTFilesOrchestrator alloc]initWithDirectory:self.cacheDirectory performance:self.performance];
        }
        return _cacheAuthorizedFilesOrchestrator;
    }
    return nil;
}
- (void)clearAllData{
    dispatch_async(self.queue, ^{
        @try {
            [self.directory deleteAllFiles];
        }
        @catch (NSException *exception) {
            FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
        }
    });
}
- (void)setIgnoreFilesAgeWhenReading:(BOOL)ignore{
    dispatch_sync(self.queue, ^{
        self.authorizedFilesOrchestrator.ignoreFilesAgeWhenReading = ignore;
    });
}
- (id<FTReader>)reader {
    FTDataReader *reader = [[FTDataReader alloc]
                            initWithQueue:self.queue
                            fileReader:[[FTFileReader alloc] initWithOrchestrator:self.authorizedFilesOrchestrator]];
    return reader;
}

@end
