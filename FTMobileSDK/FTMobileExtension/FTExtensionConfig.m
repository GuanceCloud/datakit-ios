//
//  FTExtensionConfig.m
//  FTMobileExtension
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTExtensionConfig.h"

@implementation FTExtensionConfig
- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier{
    self = [super init];
    if(self){
        _groupIdentifier = groupIdentifier;
    }
    return self;
}
- (instancetype)copyWithZone:(NSZone *)zone {
    FTExtensionConfig *options = [[[self class] allocWithZone:zone] init];
    options.enableSDKDebugLog = self.enableSDKDebugLog;
    options.enableTrackAppCrash = self.enableTrackAppCrash;
    options.enableAutoTraceResource = self.enableAutoTraceResource;
    options.groupIdentifier = self.groupIdentifier;
    return options;
}
@end
