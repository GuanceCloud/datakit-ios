//
//  FTTestUtils.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/11/29.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "FTTestUtils.h"
#import <QuartzCore/QuartzCore.h>

@implementation FTTestUtils
+ (CFTimeInterval)functionElapsedTime:(dispatch_block_t)block{
    CFTimeInterval startTime = CACurrentMediaTime();
    if (block) {
        block();
    }
    CFTimeInterval endTime = CACurrentMediaTime();
    return endTime - startTime;
}
+ (NSData *)transStreamToData:(NSInputStream *)inputStream{
    [inputStream open];
    
    // 3. Create buffer and data container
    uint8_t buffer[4096];
    NSMutableData *mutableData = [NSMutableData data];
    NSInteger bytesRead = 0;
    
    // 4. Loop read stream data
    while ([inputStream hasBytesAvailable]) {
        bytesRead = [inputStream read:buffer maxLength:sizeof(buffer)];
        if (bytesRead > 0) {
            [mutableData appendBytes:buffer length:bytesRead];
        } else if (bytesRead < 0) {
            // Handle read error
            NSLog(@"Failed to read stream data");
            break;
        }
    }
    // 5. Close stream and return result
    [inputStream close];
    return [mutableData copy];
}
+ (unsigned long long)base36ToDecimal:(NSString *)str {
    NSString *str36 = str.copy;
    NSString *param = @"0123456789abcdefghijklmnopqrstuvwxyz";
    unsigned long long num = 0;
    for (unsigned long long i = 0; i < str36.length; i++) {
        for (NSInteger j = 0; j < param.length; j++) {
            char iChar = [str36 characterAtIndex:i];
            char jChar = [param characterAtIndex:j];
            if (iChar == jChar) {
                unsigned long long n = j * pow(36, str36.length - i - 1);
                num += n;
                break;
            }
        }
    }
    return num;
}
@end
