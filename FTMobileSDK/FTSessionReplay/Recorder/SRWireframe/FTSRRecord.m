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
#import "NSDate+FTUtil.h"
#import "FTLog+Private.h"
#import "FTConstants.h"
#import "FTTouchSnapshot.h"
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
-(instancetype)initWithData:(FTSRBaseFrame *)data timestamp:(long long)timestamp{
    self = [super initWithTimestamp:timestamp];
    if(self){
        self.type = 11;
        self.data = data;
    }
    return self;
}
@end
@implementation FTSRMetaRecord
-(instancetype)initWithTimestamp:(long long)timestamp{
    return [super initWithType:4 timestamp:timestamp];
}
-(instancetype)initWithViewTreeSnapshot:(FTViewTreeSnapshot *)viewTreeSnapshot{
    self = [self initWithTimestamp:[viewTreeSnapshot.date ft_millisecondTimeStamp]];
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
@implementation FTSRIncrementalData
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
@interface MutationData ()
@property (nonatomic, assign,readwrite) BOOL isError;

@end
@implementation MutationData
-(instancetype)init{
    self = [super init];
    if(self){
        self.isError = NO;
        self.source = 0;
    }
    return self;
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
    }
    NSMutableArray *removalOffsets = [NSMutableArray new];
    int runningOffset = 0;
    for (int i = 0; i<oa.count; i++) {
        removalOffsets[i] = @(runningOffset);
        if([oa[i] intValue]<0){
            Removes *remove = [[Removes alloc]init];
            remove.identifier = lastWireframes[i].identifier;
            [removes addObject:remove];
            runningOffset += 1;
        }
    }
    runningOffset = 0;
    for (int i = 0; i< na.count; i++) {
        int indexInOld = [na[i] intValue];
        if(indexInOld<0){
            Adds *add = [[Adds alloc]init];
            if (i - 1 >= 0){
                int64_t pre = newWireframes[i-1].identifier;
                add.previousId = @(pre);
            }
            add.wireframe = newWireframes[i];
            [adds addObject:add];
            runningOffset += 1;
        }else{
            int removalOffset = [removalOffsets[indexInOld] intValue];
            if ((indexInOld - removalOffset + runningOffset) != i) {
                Removes *remove = [[Removes alloc]init];
                remove.identifier = lastWireframes[indexInOld].identifier;
                [removes addObject:remove];
                Adds *add = [[Adds alloc]init];
                if (i - 1 >= 0){
                    int64_t pre = newWireframes[i-1].identifier;
                    add.previousId = @(pre);
                }
                add.wireframe = newWireframes[i];
                [adds addObject:add];
            }else{
                NSError *error = nil;
                FTSRWireframe *update = [lastWireframes[indexInOld] compareWithNewWireFrame:newWireframes[i] error:&error];
                if(error){
                    self.isError = YES;
                    return;
                }
                if(update){
                    [updates addObject:update];
                }
            }
        }
    }
    self.removes = removes;
    self.updates = updates;
    self.adds = adds;
}
- (BOOL)isEmpty{
    return !(self.removes.count>0 || self.updates.count>0 || self.adds.count>0);
}
@end
@implementation ViewportResizeData
-(instancetype)initWithViewportSize:(CGSize)viewportSize{
    self = [super init];
    if(self){
        self.source = 4;
        _width = roundf(viewportSize.width);
        _height = roundf(viewportSize.height);
    }
    return self;

}
-(instancetype)init{
    return [self initWithViewportSize:CGSizeZero];
}
@end
@implementation PointerInteractionData
-(instancetype)init{
    self = [super init];
    if(self){
        self.source = 9;
    }
    return self;
}
-(instancetype)initWithTouch:(FTTouchCircle *)touch{
    self = [self init];
    if(self){
        self.x = roundf(touch.position.x);
        self.y = roundf(touch.position.y);
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

@implementation FTEnrichedRecord

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
        if (@available(iOS 11.0, *)) {
            NSError *error;
            FTEnrichedResource *resource = [NSKeyedUnarchiver unarchivedObjectOfClass:FTEnrichedResource.class fromData:data error:&error];
            return resource;
        }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSDictionary  *dict = [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
            _type = @"resource";
            _appId = dict[@"appId"];
            _identifier = dict[@"identifier"];
            _data = dict[@"data"];
        }
        
    }
    return self;
}
// 字典 Value 为 NSData 类型，使用 NSKeyedArchiver 将NSDictionary 转换成 NSData
-(NSData *)toJSONData{
    NSData* jsonData = nil;
    @try {
        if (@available(iOS 11.0, *)) {
            NSError *error;
            jsonData = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:NO error:&error];
        } else {
            NSDictionary* dict = [self toDictionary];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            jsonData = [NSKeyedArchiver archivedDataWithRootObject:dict];
#pragma clang diagnostic pop
        }
    }
    @catch (NSException *exception) {
        FTInnerLogError(@"EXCEPTION: %@", exception.description);
        return nil;
    }

    return jsonData;
}
@end

@implementation FTSRWebRecord


@end
