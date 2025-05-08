//
//  FTSnapshotProcessor.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSnapshotProcessor.h"
#import "FTViewTreeSnapshotBuilder.h"
#import "FTViewAttributes.h"
#import "FTViewAttributes.h"
#import "FTSRWireframe.h"
#import "FTSRWireframesBuilder.h"
#import "NSDate+FTUtil.h"
#import "FTSRRecord.h"
#import "FTNodesFlattener.h"
#import "FTFileWriter.h"
#import "FTConstants.h"
#import "FTModuleManager.h"
#import "FTSRUtils.h"
#import "FTTouchSnapshot.h"
#import "FTLog+Private.h"

NSTimeInterval const kFullSnapshotInterval = 20.0;

@interface FTSnapshotProcessor()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) id<FTWriter> writer;
/// 记录上一页面基本数据，用来判断是否是新页面
@property (nonatomic, strong) FTViewTreeSnapshot *lastSnapshot;
@property (nonatomic, assign) CFTimeInterval lastSnapshotTimestamp;
/// 用来比较增量数据
@property (nonatomic, strong) NSArray<FTSRWireframe *> *lastSRWireframes;
@property (nonatomic, strong) FTNodesFlattener *flattener;
@property (nonatomic, strong) NSMutableDictionary *recordsCountByViewID;
@property (nonatomic, assign) BOOL needUpdateFullSnapshot;
@end
@implementation FTSnapshotProcessor
-(instancetype)initWithQueue:(dispatch_queue_t)queue writer:(id<FTWriter>)writer{
    self = [super init];
    if(self){
        _queue = queue;
        _writer = writer;
        _flattener = [[FTNodesFlattener alloc]init];
        _recordsCountByViewID = [NSMutableDictionary new];
    }
    return self;
}
- (void)process:(FTViewTreeSnapshot *)viewTreeSnapshot touchSnapshot:(FTTouchSnapshot *)touchSnapshot{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        [weakSelf processSync:viewTreeSnapshot touchSnapshot:touchSnapshot];
    });
}
- (void)processSync:(FTViewTreeSnapshot *)viewTreeSnapshot touchSnapshot:(FTTouchSnapshot *)touchSnapshot{
    @try {
        NSMutableArray<FTSRWireframe> *wireframes = (NSMutableArray<FTSRWireframe>*)[[NSMutableArray alloc]init];
        NSArray<id <FTSRWireframesBuilder>> *nodes = [self.flattener flattenNodes:viewTreeSnapshot];
        for (id<FTSRWireframesBuilder> builder in nodes) {
            [wireframes addObjectsFromArray:[builder buildWireframes]];
        }
        // 2.将数据转换成存储要求的格式
        NSMutableArray<FTSRRecord> *records =(NSMutableArray<FTSRRecord>*)[[NSMutableArray alloc]init];
        BOOL force = NO;
        // 3.进行判断是新增，还是新的 View
        BOOL isNewView = self.lastSnapshot == nil || self.lastSnapshot.context.sessionID != viewTreeSnapshot.context.sessionID || self.lastSnapshot.context.viewID != viewTreeSnapshot.context.viewID;
        BOOL isTimeForFullSnapshot = [self isTimeForFullSnapshot];
        BOOL fullSnapshotRequired = isNewView || isTimeForFullSnapshot;
        // 3.1.新的 view 全量保存
        if (isNewView || fullSnapshotRequired){
            force = YES;
            // meta focus full
            FTSRMetaRecord *metaRecord = [[FTSRMetaRecord alloc]initWithViewTreeSnapshot:viewTreeSnapshot];
            FTSRFocusRecord *focusRecord = [[FTSRFocusRecord alloc]initWithTimestamp:[viewTreeSnapshot.context.date ft_millisecondTimeStamp]];
            focusRecord.hasFocus = YES;
            FTSRFullSnapshotRecord *fullRecord = [[FTSRFullSnapshotRecord alloc]initWithTimestamp:[viewTreeSnapshot.context.date ft_millisecondTimeStamp]];
            fullRecord.wireframes = wireframes;
            [records addObject:metaRecord];
            [records addObject:focusRecord];
            [records addObject:fullRecord];
        }else if(self.lastSRWireframes == nil){
            //3.2 有 lastSnapshot ,但未采集到 wireframe 的情况
            FTSRFullSnapshotRecord *fullRecord = [[FTSRFullSnapshotRecord alloc]initWithTimestamp:[viewTreeSnapshot.context.date ft_millisecondTimeStamp]];
            fullRecord.wireframes = wireframes;
            [records addObject:fullRecord];
        }else{
            // 3.3.1.已经存在 view ，进行增量判断，算法比较，获取 增量、减量、更新
            MutationData *mutation = [[MutationData alloc]init];
            [mutation createIncrementalSnapshotRecords:wireframes lastWireframes:self.lastSRWireframes];
            // 3.3.2.增量判断时如果发生异常，则不做增量处理，添加一个FullSnapshotRecord
            if(mutation.isError){
                FTSRFullSnapshotRecord *fullRecord = [[FTSRFullSnapshotRecord alloc]initWithTimestamp:[viewTreeSnapshot.context.date ft_millisecondTimeStamp]];
                fullRecord.wireframes = wireframes;
                [records addObject:fullRecord];
            }else if(!mutation.isEmpty){
                FTSRIncrementalSnapshotRecord *mutationRecord = [[FTSRIncrementalSnapshotRecord alloc]initWithData:mutation timestamp:[viewTreeSnapshot.date ft_millisecondTimeStamp]];
                [records addObject:mutationRecord];
            }
            // 3.3.3.页面尺寸是否发生变化，横屏竖屏切换
            if(FTCGSizeAspectRatio(self.lastSnapshot.viewportSize) != FTCGSizeAspectRatio(viewTreeSnapshot.viewportSize)){
                ViewportResizeData *viewport = [[ViewportResizeData alloc]initWithViewportSize:viewTreeSnapshot.viewportSize];
                FTSRIncrementalSnapshotRecord *viewportRecord = [[FTSRIncrementalSnapshotRecord alloc]initWithData:viewport timestamp:[viewTreeSnapshot.date ft_millisecondTimeStamp]];
                [records addObject:viewportRecord];
            }
        }
        // 4.将 touches 看做增量添加
        if (touchSnapshot!=nil){
            for (FTTouchCircle *touch in touchSnapshot.touches) {
                PointerInteractionData *pointer = [[PointerInteractionData alloc]initWithTouch:touch];
                FTSRIncrementalSnapshotRecord *pointerRecord = [[FTSRIncrementalSnapshotRecord alloc]initWithData:pointer timestamp:touchSnapshot.timestamp];
                [records addObject:pointerRecord];
            }
        }
        // 5.数据写入
        if(records.count>0){
            FTEnrichedRecord *fullRecord = [[FTEnrichedRecord alloc]initWithContext:viewTreeSnapshot.context records:records];
            // 5.1. 将页面采集情况同步给 RUM-View
            [self trackRecord:fullRecord];
            // 5.2. 数据写入文件
            NSData *data = [fullRecord toJSONData];
            if(data){
                [self.writer write:data forceNewFile:force];
                // 6.记录本次数据用于与下次数据比较
                self.lastSnapshot = viewTreeSnapshot;
                self.lastSRWireframes = wireframes;
            }else{
                self.lastSRWireframes = nil;
                FTInnerLogError(@"[Session Replay] Snapshot Records to Json Data error");
            }
        }
    } @catch (NSException *exception) {
        self.lastSRWireframes = nil;
        FTInnerLogError(@"[Session Replay] EXCEPTION: %@", exception.description);
    }
}
- (void)changeWriter:(id<FTWriter>)writer needUpdateFullSnapshot:(BOOL)update{
    _writer = writer;
    _needUpdateFullSnapshot = update;
}
- (void)trackRecord:(FTEnrichedRecord *)record{
    NSString *key = record.viewID;
    NSDictionary *existingValue = [self.recordsCountByViewID valueForKey:key];
    NSUInteger count = record.records.count;
    if(existingValue!=nil){
        count = [existingValue[FT_RECORDS_COUNT] integerValue] + count;
    }
    self.recordsCountByViewID[key] = @{
        FT_RECORDS_COUNT:@(count),
    };
    // TODO: 是否使用协议代理替换单例
    [[FTModuleManager sharedInstance] postMessage:FTMessageKeyRecordsCountByViewID message:[self.recordsCountByViewID mutableCopy]];
}
- (BOOL)isTimeForFullSnapshot{
    if(self.needUpdateFullSnapshot){
        CFTimeInterval currentTime = CACurrentMediaTime();
        if (currentTime - self.lastSnapshotTimestamp >= kFullSnapshotInterval) {
            self.lastSnapshotTimestamp = currentTime;
            return YES;
        }
    }
    return NO;
}

@end
