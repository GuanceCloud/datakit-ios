//
//  FTSRViewID.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSRViewID.h"
#import "UIView+FTSR.h"
#import "FTSRWireframesBuilder.h"
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
- (int)SRViewID:(UIView *)view nodeRecorder:(id<FTSRWireframesRecorder>)nodeRecorder{
    if (view.SRNodeID && view.SRNodeID[nodeRecorder.identifier]){
        return [view.SRNodeID[nodeRecorder.identifier] intValue];
    }else{
        int viewId = [self getNextID];
        if(view.SRNodeID != nil){
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:view.SRNodeID];
            [dict setValue:@(viewId) forKey:nodeRecorder.identifier];
            view.SRNodeID = dict;
        }else{
            view.SRNodeID = @{nodeRecorder.identifier:@(viewId)};
        }
        
        return viewId;
    }
}
- (int)getNextID{
    int nextID = self.currentID;
    self.currentID = self.currentID < self.maxID ? (self.currentID + 1) : 0 ;
    return nextID;
}
- (NSArray*)SRViewIDs:(UIView *)view size:(int)size nodeRecorder:(id<FTSRWireframesRecorder>)nodeRecorder{
    NSArray *viewIDs = view.SRNodeIDs[nodeRecorder.identifier];
    if (viewIDs && viewIDs.count == size){
        return viewIDs;
    }
    NSMutableArray *ids = [NSMutableArray new];
    for (int i=0; i<size;i++){
        [ids addObject:@([self getNextID])];
    }
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if(view.SRNodeIDs){
        [dict addEntriesFromDictionary:view.SRNodeIDs];
    }
    [dict setValue:ids forKey:nodeRecorder.identifier];
    view.SRNodeIDs = dict;
    return ids;
}
@end
