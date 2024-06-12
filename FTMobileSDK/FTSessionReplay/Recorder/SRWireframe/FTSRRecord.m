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
    self = [self initWithTimestamp:111111];
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
        @"href":@"data.href",
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
        @"hasFocus":@"data.hasFocus",
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
/// TODO: 增量逻辑确认
-(void)createIncrementalSnapshotRecords:(NSArray<FTSRWireframe *>*)newWireframes lastWireframes:(NSArray<FTSRWireframe *>*)lastWireframes{
    NSMutableDictionary<NSNumber*,Sampler*> *table = [[NSMutableDictionary alloc]init];
    NSMutableArray<Removes> *removes = (NSMutableArray<Removes> *)[NSMutableArray new];
    NSMutableArray<Adds> *adds = (NSMutableArray<Adds> *)[NSMutableArray new];
    NSMutableArray<FTSRWireframe> *updates = (NSMutableArray<FTSRWireframe>*)[NSMutableArray new];
    for(int i=0;i<newWireframes.count;i++){
        FTSRWireframe *new = newWireframes[i];
        table[@(new.identifier)] = [[Sampler alloc]initNewIndex:@(i) oldIndex:@(-1)];
    }
    for(int i=0;i<lastWireframes.count;i++){
        FTSRWireframe *old = lastWireframes[i];
        if (!table[@(old.identifier)]){
            Removes *remove = [[Removes alloc]init];
            remove.identifier = old.identifier;
            [removes addObject:remove];
        }else{
            table[@(old.identifier)].inOldIndex = @(i);
        }
    }
    
    for (NSNumber *identifier in table.allKeys) {
        Sampler *dict = table[identifier];
        int newIndex = [dict.inNewIndex intValue];
        int oldIndex = [dict.inOldIndex intValue];
        if (oldIndex>=0){
            FTSRWireframe *update = [lastWireframes[oldIndex] compareWithNewWireFrame:newWireframes[newIndex]];
            if(update){
                [updates addObject:update];
            }
        }else{
            Adds *add = [[Adds alloc]init];
            if (newIndex - 1 >= 0){
                int pre = newWireframes[newIndex-1].identifier;
                add.previousId = @(pre).stringValue;
            }
            add.wireframe = newWireframes[newIndex];
            [adds addObject:add];
        }
    }
    self.removes = removes.count>0?removes:nil;
    self.updates = updates.count>0?updates:nil;
    self.adds = adds.count>0?adds:nil;
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
        self.x = touch.point.x;
        self.y = touch.point.y;
        self.pointerId = touch.identifier;
        switch (touch.state) {
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
        _viewID = context.viewID;
        _records = records;
        _firstTimestamp = INT_MAX;
        _lastTimestamp = INT_MIN;
        for (FTSRRecord *record in records) {
            if ([record isKindOfClass:FTSRFullSnapshotRecord.class]){
                _hasFullSnapshot = YES;
            }
            _firstTimestamp = MIN(_firstTimestamp, record.timestamp);
            _lastTimestamp = MAX(_lastTimestamp, record.timestamp);
        }
    }
    return self;
}


@end
