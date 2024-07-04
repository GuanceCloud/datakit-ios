//
//  FTRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/1.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTMobileConfig.h"

NS_ASSUME_NONNULL_BEGIN
@class FTWindowObserver,FTSRContext,FTTouchCircle,FTSnapshotProcessor,FTResourceProcessor;
@protocol FTWriter;
@interface FTRecorder : NSObject
@property (nonatomic, strong) FTSnapshotProcessor *snapshotProcessor;
@property (nonatomic, strong) FTResourceProcessor *resourceProcessor;
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer writer:(id<FTWriter>)writer;
-(void)taskSnapShot:(FTSRContext *)context touches:(NSMutableArray <FTTouchCircle *> *)touches;
@end

NS_ASSUME_NONNULL_END
