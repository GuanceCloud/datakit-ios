//
//  FTPackageIdGenerator.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTPackageIdGenerator : NSObject
+ (NSString *)generatePackageId:(NSString *)serial count:(NSInteger)count;
@end

NS_ASSUME_NONNULL_END
