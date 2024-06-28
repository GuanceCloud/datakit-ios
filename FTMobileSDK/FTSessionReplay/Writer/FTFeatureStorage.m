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
@interface FTFeatureStorage()
@property (nonatomic, copy) NSString *featureName;
@property (nonatomic, strong) FTFilesOrchestrator *authorizedFilesOrchestrator;
// TODO:隐私条例
//@property (nonatomic, strong) FTFilesOrchestrator *unauthorizedFilesOrchestrator;
@property (nonatomic, strong) FTPerformancePreset *performance;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) FTDirectory *directory;
@end
@implementation FTFeatureStorage

-(instancetype)initWithFeatureName:(NSString *)featureName queue:(dispatch_queue_t)queue performance:(FTPerformancePreset *)performance{
    self = [super init];
    if(self){
        _featureName = featureName;
        _queue = queue;
        _performance = performance;
        _directory = [[FTDirectory alloc]initWithSubdirectoryPath:@"sessionReplay"];
    }
    return self;
}
- (id<FTWriter>)writer{
    FTFileWriter *fileWriter = [[FTFileWriter alloc]initWithOrchestrator:self.authorizedFilesOrchestrator queue:self.queue];
    return fileWriter;
}
-(FTFilesOrchestrator *)authorizedFilesOrchestrator{
    if(!_authorizedFilesOrchestrator){
        _authorizedFilesOrchestrator = [[FTFilesOrchestrator alloc]initWithDirectory:self.directory performance:self.performance];
    }
    return _authorizedFilesOrchestrator;
}
- (void)clearUnauthorizedData{
    
}
- (void)clearAllData{
    dispatch_async(self.queue, ^{
        [self.directory deleteAllFiles];
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
