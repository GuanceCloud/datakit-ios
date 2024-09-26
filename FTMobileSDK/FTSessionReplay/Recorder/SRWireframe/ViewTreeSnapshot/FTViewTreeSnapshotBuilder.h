//
//  FTViewTreeSnapshotBuilder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTSRContext;
@protocol FTSRWireframesRecorder;
@interface FTViewTreeSnapshotBuilder : NSObject
@property (nonatomic, strong) NSArray<id <FTSRWireframesRecorder>> *recorders;
- (FTViewTreeSnapshot *)takeSnapshot:(UIView *)rootView context:(FTSRContext *)context;
-(instancetype)initWithAdditionalNodeRecorders:(nullable NSArray <id <FTSRWireframesRecorder>>*)additionalNodeRecorders;
@end

NS_ASSUME_NONNULL_END
