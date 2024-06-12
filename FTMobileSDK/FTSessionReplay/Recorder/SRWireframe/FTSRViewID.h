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

@interface FTSRViewID : NSObject
- (int)SRViewID:(UIView *)view;
- (NSArray*)SRViewIDs:(UIView *)view size:(int)size;
@end

NS_ASSUME_NONNULL_END
