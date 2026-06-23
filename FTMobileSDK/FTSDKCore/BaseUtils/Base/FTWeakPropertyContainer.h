//
//  FTWeakPropertyContainer.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/2/20.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTWeakPropertyContainer : NSObject
@property (readonly, nonatomic, weak, nullable) id weakProperty;

+ (instancetype)containerWithWeakProperty:(nullable id)weakProperty;
@end

NS_ASSUME_NONNULL_END
