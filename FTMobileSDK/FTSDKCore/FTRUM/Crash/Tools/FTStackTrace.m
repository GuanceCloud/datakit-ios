//
//  FTStackTrace.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTStackTrace.h"

@implementation FTStackTrace
-(instancetype)initWithFrames:(NSArray<FTFrame *> *)frames{
    self = [super init];
    if(self){
        _frames = frames;
    }
    return self;
}
@end
