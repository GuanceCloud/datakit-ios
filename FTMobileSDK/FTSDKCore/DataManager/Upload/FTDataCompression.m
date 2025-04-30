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
NSData *bigEndianUInt32ToData(uint32_t value) {
    uint8_t bytes[4];
      
    // 手动将每个字节放入数组中，以大端顺序
    bytes[0] = (value >> 24) & 0xFF;
    bytes[1] = (value >> 16) & 0xFF;
    bytes[2] = (value >> 8) & 0xFF;
    bytes[3] = value & 0xFF;
      
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}
+ (nullable NSData *)deflate:(NSData *)data{
    if (data.length == 0){
        return nil;
    }
    uint8_t bytes[] = {0x78, 0x5e};
    NSData *header = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSData *raw = [self rowCompress:data];
    if(raw == nil){
        return nil;
    }
    UInt32 checksum = [self adler32:data];
    NSData *checksumData = bigEndianUInt32ToData(checksum);
    if (data.length>header.length+raw.length+checksumData.length){
        NSMutableData *result = [NSMutableData dataWithData:header];
        [result appendData:raw];
        [result appendData:checksumData];
        return result;
    }
    return nil;
}
+ (nullable NSData *)rowCompress:(NSData *)data{
    if (!data) {
        return nil;
    }
    if (@available(iOS 13.0,tvOS 13.0,macOS 10.15, *)) {
        NSError *error;
        return [data compressedDataUsingAlgorithm:NSDataCompressionAlgorithmZlib error:&error];
    } else {
        NSMutableData* rData = [[NSMutableData alloc] initWithLength:[data length]];
        rData.length = compression_encode_buffer(rData.mutableBytes, [data length], data.bytes, [data length], nil, COMPRESSION_ZLIB);
        if (rData.length <= 0) {
            return nil;
        }
        return rData;
    }
}
+(UInt32 )adler32:(NSData*)data{
    const Bytef *bytes = (const Bytef *)[data bytes];
    uInt len = (uInt)[data length];
    uLong adler = adler32(1, Z_NULL, 0); // 初始化Adler-32为1
    adler = adler32(adler, bytes, len); // 计算校验和
    return (UInt32)adler;
}
+ (NSData *)gzip:(NSData *)data{
    if (data.length == 0){
        return nil;
    }
    
    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    stream.avail_in = (uint)data.length;
    stream.next_in = (Bytef *)(void *)data.bytes;
    stream.total_out = 0;
    stream.avail_out = 0;
    
    static const NSUInteger ChunkSize = 16384; // 16kb
    
    NSMutableData *output = nil;
    if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK)
    {
        output = [NSMutableData dataWithLength:ChunkSize];
        while (stream.avail_out == 0)
        {
            if (stream.total_out >= output.length)
            {
                output.length += ChunkSize;
            }
            stream.next_out = (uint8_t *)output.mutableBytes + stream.total_out;
            stream.avail_out = (uInt)(output.length - stream.total_out);
            deflate(&stream, Z_FINISH);
        }
        deflateEnd(&stream);
        output.length = stream.total_out;
    }
    return output;
}
+ (BOOL)isGzippedData:(NSData *)data{
    const UInt8 *bytes = (const UInt8 *)data.bytes;
    return (data.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b);
}
+ (BOOL)isDeflateData:(NSData *)data{
    const UInt8 *bytes = (const UInt8 *)data.bytes;
    return (data.length >= 2 && bytes[0] == 0x78 && bytes[1] == 0x5e);
}
@end
