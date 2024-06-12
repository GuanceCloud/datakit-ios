//
//  FTSRViewID.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSRViewID.h"
#import "UIView+FTSR.h"
@interface FTSRViewID()
@property (nonatomic, assign) int currentID;
@property (nonatomic, assign) int maxID;
@end
@implementation FTSRViewID
-(instancetype)init{
    return [self initWithCurrentID:0 maxID:INT32_MAX];
}
-(instancetype)initWithCurrentID:(int)currentID maxID:(int)maxID{
    self = [super init];
    if(self){
        _currentID = currentID;
        _maxID = maxID;
    }
    return self;
}
- (int)SRViewID:(UIView *)view{
    if (view.SRViewID >= 0){
        return view.SRViewID;
    }else{
        int viewid = [self getNextID];
        view.SRViewID = viewid;
        return viewid;
    }
}
- (int)getNextID{
    int nextID = self.currentID;
    self.currentID = self.currentID < self.maxID ? (self.currentID + 1) : 0 ;
    return nextID;
}
- (NSArray*)SRViewIDs:(UIView *)view size:(int)size{
    NSArray *viewIDs = view.SRViewIDs;
    if (viewIDs && viewIDs.count == size){
        return viewIDs;
    }
    NSMutableArray *ids = [NSMutableArray new];
    for (int i=0; i<size;i++){
        [ids addObject:@([self getNextID])];
    }
    view.SRViewIDs = ids;
    return ids;
}
@end
