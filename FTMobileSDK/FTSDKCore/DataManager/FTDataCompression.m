//
//  FTDataCompression.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/10/16.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDataCompression.h"
#import <Foundation/Foundation.h>
#import "compression.h"
#import <zlib.h>
@implementation FTDataCompression
+ (NSData *)deflate:(NSData *)data{
    uint8_t bytes[] = {0x78, 0x5e};
    NSData *header = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSData *raw = [self rowCompress:data];
    NSData *checksum = [self adler32:data];
    if(data.length>header.length+raw.length+checksum.length){
        NSMutableData *result = [NSMutableData dataWithData:header];
        [result appendData:raw];
        [result appendData:checksum];
        return result;
    }
    return nil;
}
+ (NSData *)rowCompress:(NSData *)data{
    if (!data) {
        return nil;
    }
    const uint8_t *srcBytes = [data bytes];
    size_t srcSize = [data length];
    uint8_t *buffer = malloc(srcSize);
    if (!buffer) {
        return nil;
    }
    size_t compressedSize = compression_encode_buffer(buffer, srcSize, srcBytes, srcSize, NULL, COMPRESSION_ZLIB);
    if (compressedSize <= 0) {
        free(buffer);
        return nil;
    }
    
    // 创建并返回压缩后的NSData对象
    NSData *compressedData = [NSData dataWithBytes:buffer length:compressedSize];
    
    // 释放临时分配的内存
    free(buffer);
    return compressedData;
}
+(NSData *)adler32:(NSData*)data{
    if (!data) {
        return nil;
    }
    
    const Bytef *bytes = (const Bytef *)[data bytes];
    uInt len = (uInt)[data length];
    uLong adler = adler32(1, Z_NULL, 0); // 初始化Adler-32为1
    adler = adler32(adler, bytes, len); // 计算校验和
    
    // 将uLong（通常是uint32_t）转换为NSData
    UInt32 checksum = (UInt32)adler;
    NSData *checksumData = [NSData dataWithBytes:&checksum length:sizeof(checksum)];
    
    return checksumData;
}
@end
