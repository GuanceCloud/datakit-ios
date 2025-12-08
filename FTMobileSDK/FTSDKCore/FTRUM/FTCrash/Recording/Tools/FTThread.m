//
//  FTThread.m
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTThread.h"

@implementation FTThread
- (instancetype)initWithThreadId:(NSNumber *)threadId{
    self = [super init];
    if(self){
        _threadId = threadId;
    }
    return self;
}
@end
