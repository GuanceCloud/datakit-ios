//
//  FTCompression.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/10.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTCompression.h"
#import "zlib.h"

@implementation FTCompression
- (NSData *)compress:(NSData *)data{
    return [self compressWithLevel:6 data:data];
}
- (NSData *)compressWithLevel:(int)level data:(NSData *)data{
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

@end
