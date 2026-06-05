//
//  FTCoreDirectory.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTCoreDirectory.h"
#import "FTDirectory.h"
#import "FTFeatureDirectories.h"

@implementation FTCoreDirectory

- (instancetype)initWithDirectory:(FTDirectory *)directory{
    self = [super init];
    if (self) {
        _directory = directory;
    }
    return self;
}

- (instancetype)initWithSubdirectoryPath:(NSString *)path{
    return [self initWithDirectory:[[FTDirectory alloc]initWithSubdirectoryPath:path]];
}

- (FTFeatureDirectories *)featureDirectoriesForFeatureName:(NSString *)featureName{
    FTDirectory *granted = [self.directory createSubdirectoryWithPath:featureName];
    if (!granted) {
        return nil;
    }
    FTDirectory *pending = [self.directory createSubdirectoryWithPath:[featureName stringByAppendingString:@".pending"]];
    FTDirectory *errorSampled = [self.directory createSubdirectoryWithPath:[featureName stringByAppendingString:@".cache"]];
    return [[FTFeatureDirectories alloc]initWithGranted:granted
                                                pending:pending
                                           errorSampled:errorSampled];
}

@end
