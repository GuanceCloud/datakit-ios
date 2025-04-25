//
//  FTSRViewID.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/3.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@protocol FTSRWireframesRecorder;
@interface FTSRViewID : NSObject
- (int64_t)SRViewID:(UIView *)view nodeRecorder:(id<FTSRWireframesRecorder>)nodeRecorder;
- (NSArray*)SRViewIDs:(UIView *)view size:(int)size nodeRecorder:(id<FTSRWireframesRecorder>)nodeRecorder;
@end

NS_ASSUME_NONNULL_END
