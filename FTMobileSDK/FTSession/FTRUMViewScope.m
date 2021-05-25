//
//  FTRUMViewScope.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMViewScope.h"
#import "FTRUMActionScope.h"
@interface FTRUMViewScope()<FTRUMScopeProtocol>
@property (nonatomic, strong) FTRUMActionScope *actionScope;
@property (nonatomic, strong) NSMutableArray<FTRUMActionScope *> *actionArray;
@property (nonatomic, copy) NSString *viewid;
@property (nonatomic, assign) BOOL isActive;
@end
@implementation FTRUMViewScope
-(instancetype)init{
    self = [super init];
    if (self) {
        self.assistant = self;
        self.isActive = YES;
    }
    return self;
}
- (void)addRumActionScope:(FTRUMActionScope *)action{
//    self.actionArray
    
    self.actionScope = action;
    self.actionScope.handler = ^(){
        
        
    };
    
}
- (BOOL)process:(FTRUMModel *)commond{
    
    
    return NO;
}

@end
