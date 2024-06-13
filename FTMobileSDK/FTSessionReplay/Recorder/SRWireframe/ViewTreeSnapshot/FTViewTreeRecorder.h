//
//  FTViewTreeRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeRecordingContext;
@protocol FTSRWireframesRecorder;
@interface FTViewTreeRecorder : NSObject
@property (nonatomic, strong) NSArray<id<FTSRWireframesRecorder>> *nodeRecorders;
- (void)record:(NSMutableArray *)nodes resources:(NSMutableArray *)resource view:(UIView *)view context:(FTViewTreeRecordingContext *)context;
@end

NS_ASSUME_NONNULL_END
