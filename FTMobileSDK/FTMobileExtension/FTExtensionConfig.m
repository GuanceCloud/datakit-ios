//
//  FTExtensionConfig.m
//  FTMobileExtension
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTExtensionConfig.h"

@implementation FTExtensionConfig
-(instancetype)init{
    return [self initWithGroupIdentifier:@""];
}
- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier{
    self = [super init];
    if(self){
        _groupIdentifier = groupIdentifier;
        _memoryMaxCount = 1000;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTExtensionConfig *options = [[[self class] allocWithZone:zone] init];
    options.enableSDKDebugLog = self.enableSDKDebugLog;
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options.enableTracerAutoTrace = self.enableTracerAutoTrace;
    options.enableRUMAutoTraceResource = self.enableRUMAutoTraceResource;
    options.groupIdentifier = self.groupIdentifier;
    options.memoryMaxCount = self.memoryMaxCount;
    return options;
}
@end
