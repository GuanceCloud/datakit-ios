//
//  FTRecordWriter.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTRecordWriter.h"
#import "FTFileWriter.h"
#import "FTFeatureScope.h"

@interface FTRecordWriter()
@property (nonatomic, strong) FTFeatureScope *featureScope;
@end

@implementation FTRecordWriter

- (instancetype)initWithFeatureScope:(FTFeatureScope *)featureScope{
    self = [super init];
    if(self){
        _featureScope = featureScope;
    }
    return self;
}

- (BOOL)isErrorSampled{
    return self.featureScope.isErrorSampled;
}

- (void)write:(NSData *)data{
    [self write:data forceNewFile:NO];
}

- (void)write:(NSData *)data forceNewFile:(BOOL)force{
    [self.featureScope eventWriteContext:^(__unused FTFeatureContext *context, id<FTWriter> writer) {
        [writer write:data forceNewFile:force];
    }];
}

@end
