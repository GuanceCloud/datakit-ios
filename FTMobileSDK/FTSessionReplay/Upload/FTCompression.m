//
//  FTCompression.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/10.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTCompression.h"
#import "compression.h"
#import "zlib.h"

@implementation FTCompression
+ (NSData *)compress:(NSData *)data{
    return [self compressWithLevel:6 data:data];
}
+ (NSData *)compressWithLevel:(int)level data:(NSData *)data{
    z_stream zStream;
    bzero(&zStream, sizeof(zStream));
    
    zStream.zalloc = Z_NULL;
    zStream.zfree = Z_NULL;
    zStream.opaque = Z_NULL;
    // 剩余的需要压缩字指针
    zStream.next_in = (Bytef *) data.bytes;
    // 剩余的需要压缩字节数
    zStream.avail_in = (uInt) data.length;
    // 目前已经输出的字节数
    zStream.total_out = 0;
    OSStatus status = deflateInit(&zStream,level);
    
    if (status != Z_OK) {
        return nil;
    }
    static NSInteger kZlibCompressChunkSize = 2048;
    NSMutableData *compressedData = [NSMutableData dataWithLength:kZlibCompressChunkSize];
    do {
        if ((status == Z_BUF_ERROR) || (zStream.total_out == compressedData.length)) {
            [compressedData increaseLengthBy:kZlibCompressChunkSize];
        }
        zStream.next_out = (Bytef *)compressedData.bytes + zStream.total_out;
        zStream.avail_out = (uInt)(compressedData.length - zStream.total_out);
        status = deflate(&zStream, Z_FINISH);
    } while ((status == Z_BUF_ERROR) || (status == Z_OK));
    
    status = deflateEnd(&zStream);
    
    if ((status != Z_OK) && (status != Z_STREAM_END)) {
        return nil;
    }
    compressedData.length = zStream.total_out;
    return compressedData;
}
+ (NSData *)encode:(NSData *)data{
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
