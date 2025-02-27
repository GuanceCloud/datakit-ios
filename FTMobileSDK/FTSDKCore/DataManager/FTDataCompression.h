//
//  FTDataCompression.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/10/16.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTDataCompression : NSObject
+ (nullable NSData *)deflate:(NSData *)data;
+ (nullable NSData *)gzip:(NSData *)data;
@end

NS_ASSUME_NONNULL_END
