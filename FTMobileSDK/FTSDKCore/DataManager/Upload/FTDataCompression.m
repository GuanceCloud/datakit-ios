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

+ (nullable NSData *)deflate:(NSData *)data{
    if (!data || data.length == 0){
        return nil;
    }
    uint8_t bytes[] = {0x78, 0x5e};
    NSData *header = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSData *raw = [self rawCompress:data];
    if(raw == nil){
        return nil;
    }
    NSData *checksumData = [self adler32:data];
    if (!checksumData) {
        return nil;
    }
    NSUInteger compressedTotalLength = header.length + raw.length + checksumData.length;
    if (compressedTotalLength >= data.length) {
        return nil;
    }
    
    NSMutableData *result = [NSMutableData dataWithData:header];
    [result appendData:raw];
    [result appendData:checksumData];
    
    return result;
}
+ (nullable NSData *)rawCompress:(NSData *)data{
    if (!data || !data.bytes) {
        return nil;
    }
    size_t sourceSize = data.length;
    size_t bufferSize = sourceSize + (sourceSize * 5 / 100) + 16;
    uint8_t *buffer = malloc(bufferSize);
    if (!buffer) return nil;
    
    size_t compressedSize = compression_encode_buffer(buffer, bufferSize,
                                                      data.bytes, sourceSize,
                                                      NULL,
                                                      COMPRESSION_ZLIB);
    
    if (compressedSize == 0) {
        free(buffer);
        return nil;
    }
    
    return [NSData dataWithBytesNoCopy:buffer length:compressedSize freeWhenDone:YES];
}
+ (nullable NSData *)adler32:(NSData *)data {
    if (!data || !data.bytes) {
        return nil;
    }
    uLong adler = adler32(1L, data.bytes, (uInt)data.length);
    
    uint32_t bigEndianAdler = CFSwapInt32HostToBig((uint32_t)adler);
    
    return [NSData dataWithBytes:&bigEndianAdler length:sizeof(uint32_t)];
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
