//
//  FTDataCompression+Test.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/10/28.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "FTDataCompression.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTDataCompression ()
+ (NSData *)rowCompress:(NSData *)data;
+(UInt32 )adler32:(NSData*)data;
+ (BOOL)isGzippedData:(NSData *)data;
+ (BOOL)isDeflateData:(NSData *)data;
@end

NS_ASSUME_NONNULL_END
