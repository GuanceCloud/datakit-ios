//
//  FTCompression.h
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/10.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTCompression : NSObject
- (NSData *)compress:(NSData *)data;
@end

NS_ASSUME_NONNULL_END
