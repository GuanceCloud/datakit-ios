//
//  FTSRRecord.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/29.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTSRBaseFrame.h"
#import "FTSRWireframe.h"
#import "FTTouchCircle.h"

NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTSRContext;
@protocol FTSRRecord;
@interface FTSRRecord: FTSRBaseFrame
@property (nonatomic, assign) int type;
@property (nonatomic, assign) long long timestamp;
-(instancetype)initWithTimestamp:(long long)timestamp;
@end
@protocol FTSRWireframe;
@interface FTSRFullSnapshotRecord : FTSRRecord
@property (nonatomic, strong) NSArray<FTSRWireframe> *wireframes;
@end
@interface FTSRMetaRecord : FTSRRecord
@property (nonatomic, assign) int height;
@property (nonatomic, assign) int width;
- (instancetype)initWithViewTreeSnapshot:(FTViewTreeSnapshot *)viewTreeSnapshot;
@end
@interface FTSRFocusRecord : FTSRRecord
@property (nonatomic, assign) BOOL hasFocus;
@end

@interface FTSRIncrementalSnapshotRecord : FTSRRecord
@property (nonatomic, assign) int source;
@end
@protocol Adds;
@interface Adds : FTSRBaseFrame
@property (nonatomic, copy) NSString *previousId;
@property (nonatomic, strong) FTSRWireframe *wireframe;
@end
@protocol Removes;
@interface Removes : FTSRBaseFrame
@property (nonatomic, assign) long long identifier;
@end
@interface MutationData : FTSRIncrementalSnapshotRecord
@property (nonatomic, strong) NSArray<Adds> *adds;
@property (nonatomic, strong) NSArray<Removes> *removes;
@property (nonatomic, strong) NSArray<FTSRWireframe> *updates;
-(void)createIncrementalSnapshotRecords:(NSArray<FTSRWireframe *>*)newWireframes lastWireframes:(NSArray<FTSRWireframe *>*)lastWireframes;
- (BOOL)isEmpty;
@end

@interface ViewportResizeData : FTSRIncrementalSnapshotRecord
@property (nonatomic, assign) int height;
@property (nonatomic, assign) int width;
@end

@interface PointerInteractionData : FTSRIncrementalSnapshotRecord
@property (nonatomic, assign) double x;
@property (nonatomic, assign) double y;
@property (nonatomic, assign) int pointerId;
@property (nonatomic, copy) NSString *pointerEventType;
@property (nonatomic, copy) NSString *pointerType;
-(instancetype)initWithTimestamp:(long long)timestamp touch:(FTTouchCircle *)touch;
@end

@interface FTSRFullRecord : FTSRBaseFrame
@property (nonatomic, strong) NSArray<FTSRRecord> *records;
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *applicationID;
@property (nonatomic, copy) NSString *viewID;
@property (nonatomic, assign) long long firstTimestamp;
@property (nonatomic, assign) long long lastTimestamp;
@property (nonatomic, assign) BOOL hasFullSnapshot;
-(instancetype)initWithContext:(FTSRContext*)context records:(NSArray<FTSRRecord>*)records;
@end
NS_ASSUME_NONNULL_END
