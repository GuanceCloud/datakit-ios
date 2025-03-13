//
//  FTPackageIdGenerator.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/3/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTPackageIdGenerator.h"
#import "FTBaseInfoHandler.h"
#import <unistd.h>
static NSString *const kBase62Charset = @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
static NSString *pid;
@implementation FTPackageIdGenerator
+(void)initialize{
    pid_t processID = getpid();
    pid = [self base62Encode:processID];
}
+ (NSString *)base62Encode:(int)num {
    if (num == 0) return @"0"; // 处理边界情况
    NSMutableString *result = [NSMutableString string];
    while (num > 0) {
        NSUInteger remainder = num % 62;
        [result insertString:[kBase62Charset substringWithRange:NSMakeRange(remainder, 1)] atIndex:0];
        num /= 62;
    }
    return result;
}
+ (NSString *)generate12CharBase62RandomString{
    NSMutableString *result = [NSMutableString stringWithCapacity:12];
    
    // 使用更安全的随机数生成方法（适合加密场景）
    for (NSUInteger i = 0; i < 12; i++) {
        uint32_t randomValue = 0;
        int status = SecRandomCopyBytes(kSecRandomDefault, sizeof(randomValue), (uint8_t *)&randomValue);
        
        if (status == errSecSuccess) {
            // 取模 62 确保范围在 0~61
            NSUInteger charIndex = randomValue % 62;
            [result appendString:[kBase62Charset substringWithRange:NSMakeRange(charIndex, 1)]];
        } else {
            // 安全随机失败时回退到 arc4random
            NSUInteger charIndex = arc4random_uniform(62);
            [result appendString:[kBase62Charset substringWithRange:NSMakeRange(charIndex, 1)]];
        }
    }
    return result;
}
+ (NSString *)decimalToBase36:(unsigned long)decimalNumber{
    static NSString *const base36Characters = @"0123456789abcdefghijklmnopqrstuvwxyz";
    NSMutableString *result = [NSMutableString string];
    while (decimalNumber > 0) {
        NSUInteger remainder = decimalNumber % 36;
        [result insertString:[base36Characters substringWithRange:NSMakeRange(remainder, 1)] atIndex:0];
        decimalNumber /= 36;
    }
    return result.length > 0 ? result : @"0";
}

+ (NSString *)generatePackageId:(NSString *)serial count:(NSInteger)count{
    return [NSString stringWithFormat:@"%@.%@.%lu.%@",serial,pid,(unsigned long)count,[self generate12CharBase62RandomString]];
}
@end
