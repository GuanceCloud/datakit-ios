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
@class FTWindowObserver,FTSRContext,FTTouchCircle;
@protocol FTWriter;
@interface FTRecorder : NSObject
-(instancetype)initWithWindowObserver:(FTWindowObserver *)observer writer:(id<FTWriter>)writer;
-(void)taskSnapShot:(FTSRContext *)context touches:(NSMutableArray <FTTouchCircle *> *)touches;
@end

NS_ASSUME_NONNULL_END
