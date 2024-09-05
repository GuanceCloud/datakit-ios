//
//  FTRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/1.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTWindowObserver,FTSRContext,FTTouchSnapshot,FTSnapshotProcessor,FTResourceProcessor;
@protocol FTWriter;
@interface FTRecorder : NSObject
@property (nonatomic, strong) FTSnapshotProcessor *snapshotProcessor;
@property (nonatomic, strong) FTResourceProcessor *resourceProcessor;
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer snapshotProcessor:(FTSnapshotProcessor *)snapshotProcessor resourceProcessor:(nullable FTResourceProcessor *)resourceProcessor;
-(void)taskSnapShot:(FTSRContext *)context touchSnapshot:(nullable FTTouchSnapshot *)touchSnapshot;
@end

NS_ASSUME_NONNULL_END
