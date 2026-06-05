//
//  FTFeatureDirectories.m
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import "FTFeatureDirectories.h"

@implementation FTFeatureDirectories

- (instancetype)initWithGranted:(FTDirectory *)granted
                        pending:(FTDirectory *)pending
                   errorSampled:(FTDirectory *)errorSampled{
    self = [super init];
    if (self) {
        _granted = granted;
        _pending = pending;
        _errorSampled = errorSampled;
    }
    return self;
}

@end
