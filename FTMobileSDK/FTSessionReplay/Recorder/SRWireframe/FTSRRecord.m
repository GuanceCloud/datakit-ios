//
//  FTSRRecord.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/29.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTSRRecord.h"
#import "FTSRUtils.h"
#import "FTViewAttributes.h"
#import "FTTouchCircle.h"
#import "NSDate+FTUtil.h"
@implementation FTSRRecord
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [self initWithType:0 timestamp:timestamp];
}
-(instancetype)initWithType:(int)type timestamp:(long long)timestamp{
    self = [super init];
    if(self){
        _type = type;
        _timestamp = timestamp;
    }
    return self;
}
@end
@implementation FTSRFullSnapshotRecord
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [super initWithType:10 timestamp:timestamp];
}
+(FTJSONKeyMapper *)keyMapper{
    FTJSONKeyMapper *keyMapper = [[FTJSONKeyMapper alloc]initWithModelToJSONDictionary:@{
        @"wireframes":@"data.wireframes",
    }];
    return keyMapper;
}
@end
@implementation FTSRIncrementalSnapshotRecord

-(instancetype)initWithSource:(int)source timestamp:(long long)timestamp{
    self = [super initWithTimestamp:timestamp];
    if(self){
        self.source = source;
        self.type = 11;
    }
    return self;
}
@end
@implementation FTSRMetaRecord
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [super initWithType:4 timestamp:timestamp];
}
-(instancetype)initWithViewTreeSnapshot:(FTViewTreeSnapshot *)viewTreeSnapshot{
    self = [self initWithTimestamp:[viewTreeSnapshot.date ft_nanosecondTimeStamp]];
    if(self){
        _width = viewTreeSnapshot.viewportSize.width;
        _height = viewTreeSnapshot.viewportSize.height;
    }
    return self;
}
+(FTJSONKeyMapper *)keyMapper{
    FTJSONKeyMapper *keyMapper = [[FTJSONKeyMapper alloc]initWithModelToJSONDictionary:@{
        @"height":@"data.height",
        @"width":@"data.width",
    }];
    return keyMapper;
}
@end
@implementation FTSRFocusRecord
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [super initWithType:6 timestamp:timestamp];
}
+(FTJSONKeyMapper *)keyMapper{
    FTJSONKeyMapper *keyMapper = [[FTJSONKeyMapper alloc]initWithModelToJSONDictionary:@{
        @"hasFocus":@"has_focus",
    }];
    return keyMapper;
}
@end
@implementation Adds

@end
@implementation Removes
+(FTJSONKeyMapper *)keyMapper{
    FTJSONKeyMapper *keyMapper = [[FTJSONKeyMapper alloc]initWithModelToJSONDictionary:@{
        @"identifier":@"id"
    }];
    return keyMapper;
}
@end
@interface Sampler : NSObject
@property (nonatomic) NSNumber *inNewIndex;
@property (nonatomic) NSNumber *inOldIndex;
-(instancetype)initNewIndex:(NSNumber *)newIndex oldIndex:(NSNumber *)oldIndex;
@end
@implementation Sampler
-(instancetype)initNewIndex:(NSNumber *)newIndex oldIndex:(NSNumber *)oldIndex{
    self = [super init];
    if(self){
        _inNewIndex = newIndex;
        _inOldIndex = oldIndex;
    }
    return self;
}
@end
@implementation MutationData
+(FTJSONKeyMapper *)keyMapper{
    FTJSONKeyMapper *keyMapper = [[FTJSONKeyMapper alloc]initWithModelToJSONDictionary:@{
        @"adds":@"data.adds",
        @"removes":@"data.removes",
        @"updates":@"data.updates",
    }];
    return keyMapper;
}
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [super initWithSource:0 timestamp:timestamp];
}
/// 增量逻辑：
/// 子序列相同的部分判断是否 update
/// 不同的部分考虑 add\remove
/// 子序列与子序列位置发生变化，对移动到后面的子序列进行 add\remove 操作
-(void)createIncrementalSnapshotRecords:(NSArray<FTSRWireframe *>*)newWireframes lastWireframes:(NSArray<FTSRWireframe *>*)lastWireframes{
    NSMutableDictionary<NSNumber*,Sampler*> *table = [[NSMutableDictionary alloc]init];
    NSMutableArray<Removes> *removes = (NSMutableArray<Removes> *)[NSMutableArray new];
    NSMutableArray<Adds> *adds = (NSMutableArray<Adds> *)[NSMutableArray new];
    NSMutableArray<FTSRWireframe> *updates = (NSMutableArray<FTSRWireframe>*)[NSMutableArray new];
    NSMutableArray *oa = [NSMutableArray new];
    NSMutableArray *na = [NSMutableArray new];
    for(int i=0;i<newWireframes.count;i++){
        FTSRWireframe *new = newWireframes[i];
        table[@(new.identifier)] = [[Sampler alloc]initNewIndex:@(i) oldIndex:@(-1)];
        [na addObject:@(-1)];
    }
    for(int i=0;i<lastWireframes.count;i++){
        FTSRWireframe *old = lastWireframes[i];
        Sampler *sampler =  table[@(old.identifier)];
        if(sampler){
            table[@(old.identifier)].inOldIndex = @(i);
        }else{
            table[@(old.identifier)] = [[Sampler alloc]initNewIndex:@(-1) oldIndex:@(i)];
        }
        [oa addObject:@(-1)];
    }
    for (Sampler *dict in table.allValues) {
        int newIndex = [dict.inNewIndex intValue];
        int oldIndex = [dict.inOldIndex intValue];
        if(newIndex>=0&&oldIndex>=0){
            na[newIndex] = dict.inOldIndex;
            oa[oldIndex] = dict.inNewIndex;
        }
        if(oldIndex<0){
            Adds *add = [[Adds alloc]init];
            if (newIndex - 1 >= 0){
                int pre = newWireframes[newIndex-1].identifier;
                add.previousId = @(pre).stringValue;
            }
            add.wireframe = newWireframes[newIndex];
            [adds addObject:add];
        }
        if(newIndex<0){
            Removes *remove = [[Removes alloc]init];
            remove.identifier = lastWireframes[oldIndex].identifier;
            [removes addObject:remove];
        }
    }
    NSMutableArray *removalOffsets = [NSMutableArray new];
    int runningOffset = 0;
    for (int i = 0; i<oa.count; i++) {
        removalOffsets[i] = @(runningOffset);
        if([oa[i] intValue]<0){
            runningOffset += 1;
        }
    }
    runningOffset = 0;
    for (int i = 0; i< na.count; i++) {
        int indexInOld = [na[i] intValue];
        if(indexInOld<0){
            runningOffset += 1;
        }else{
            int removalOffset = [removalOffsets[indexInOld] intValue];
            if ((indexInOld - removalOffset + runningOffset) != i) {
                Removes *remove = [[Removes alloc]init];
                remove.identifier = lastWireframes[indexInOld].identifier;
                [removes addObject:remove];
                Adds *add = [[Adds alloc]init];
                if (i - 1 >= 0){
                    int pre = newWireframes[i-1].identifier;
                    add.previousId = @(pre).stringValue;
                }
                add.wireframe = newWireframes[i];
                [adds addObject:add];
            }else{
                FTSRWireframe *update = [lastWireframes[indexInOld] compareWithNewWireFrame:newWireframes[i]];
                           if(update){
                               [updates addObject:update];
                           }
            }
        }
    }

    self.removes = removes.count>0?removes:nil;
    self.updates = updates.count>0?updates:nil;
    self.adds = adds.count>0?adds:nil;
}
- (BOOL)isEmpty{
    return !(self.removes.count>0 || self.updates.count>0 || self.adds.count>0);
}
@end
@implementation ViewportResizeData
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [super initWithSource:4 timestamp:timestamp];
}
@end
@implementation PointerInteractionData
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [super initWithSource:9 timestamp:timestamp];
}
-(instancetype)initWithTimestamp:(long long)timestamp touch:(FTTouchCircle *)touch{
    self = [self initWithTimestamp:timestamp];
    if(self){
        self.x = touch.position.x;
        self.y = touch.position.y;
        self.pointerId = touch.identifier;
        switch (touch.phase) {
            case TouchUp:
                self.pointerEventType = @"up";
                break;
            case TouchMoved:
                self.pointerEventType = @"move";
                break;
            case TouchDown:
                self.pointerEventType = @"down";
                break;
            default:
                break;
        }
        self.pointerType = @"touch";
    }
    return self;
}
@end

@implementation FTSRFullRecord

-(instancetype)initWithContext:(FTSRContext*)context records:(NSArray<FTSRRecord>*)records{
    self = [super init];
    if(self){
        _sessionID = context.sessionID;
        _applicationID = context.applicationID;
        _viewID = context.viewID;
        _records = records;
    }
    return self;
}
@end
@implementation FTEnrichedResource

-(instancetype)init{
    self = [super init];
    if(self){
        _type = @"resource";
    }
    return self;
}
-(instancetype)initWithData:(NSData *)data{
    self = [super init];
    if(self){
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        _type = @"resource";
        _appId = dict[@"appId"];
        _identifier = dict[@"identifier"];
        _data = dict[@"data"];
    }
    return self;
}
@end
