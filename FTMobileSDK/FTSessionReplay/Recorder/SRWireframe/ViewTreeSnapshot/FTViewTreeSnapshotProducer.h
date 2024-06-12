//
//  FTViewTreeSnapshot.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/7/17.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@class FTViewTreeSnapshot,FTSRContext;
@interface FTViewTreeSnapshotProducer : NSObject
- (FTViewTreeSnapshot *)takeSnapshot:(UIView *)rootView context:(FTSRContext *)context;
@end

NS_ASSUME_NONNULL_END
