//
//  FTUploadConditions.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTUploadConditions : NSObject
- (BOOL)checkForUpload;
- (void)startObserver;
- (void)cancel;
@end

NS_ASSUME_NONNULL_END
