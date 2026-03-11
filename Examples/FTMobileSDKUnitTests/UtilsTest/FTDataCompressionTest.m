//
//  FTDataCompressionTest.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/10/28.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FTDataCompression+Test.h"
#import "FTJSONUtil.h"
#import "compression.h"
#import <zlib.h>
@interface FTDataCompressionTest : XCTestCase

@end

@implementation FTDataCompressionTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}
- (void)testDataCompression_deflate_small_data{
    uint8_t bytes[] = {0};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    
    XCTAssertNil([FTDataCompression deflate:data]);
    
    NSData *rowData = [FTDataCompression rawCompress:data];
    
    uint8_t nbytes[] = {0x63, 0x00, 0x00};
    NSData *eData = [NSData dataWithBytes:nbytes length:sizeof(nbytes)];
    
    // Then
    XCTAssertTrue([rowData isEqualToData:eData]);
}
- (void)testDataCompression_deflate_big_data{
    NSDictionary *dict = @{@"a":@"123456",
                           @"b":@"234567",
                           @"c":@"qwertyuii",
                           @"d":@"qwertyuii",
                           @"e":@"qwertyuii",
    };
    NSData *jsonData = [FTJSONUtil JSONSerializeDictObject:dict];
    
    NSData *compressionData = [FTDataCompression deflate:jsonData];

    XCTAssertTrue(compressionData.length<jsonData.length);
}
- (void)testDataCompression_deflate_CalculatesAdler32{
    NSData *data = [@"Wikipedia" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *adler32Data = [FTDataCompression adler32:data];
   

    uint32_t resultBigEndian;
    [adler32Data getBytes:&resultBigEndian length:sizeof(uint32_t)];

    uint32_t resultHostEndian = CFSwapInt32BigToHost(resultBigEndian);

    // From https://en.wikipedia.org/wiki/Adler-32
    XCTAssertEqual(resultHostEndian, 300286872);

}
- (void)testDataCompression_deflate_format{
    NSDictionary *dict = @{@"a":@"123456",
                           @"b":@"234567",
                           @"c":@"qwertyuii",
                           @"d":@"qwertyuii",
                           @"e":@"qwertyuii",
    };
    NSData *jsonData = [FTJSONUtil JSONSerializeDictObject:dict];
    
    NSData *compressionData = [FTDataCompression deflate:jsonData];
    
    NSData *data = [self deflateDecompress:compressionData];
    
    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    
    NSDictionary *nDict = [FTJSONUtil dictionaryWithJsonString:str];
    XCTAssertTrue([dict isEqualToDictionary:nDict]);
}

//- (NSData *)deflateDecompress:(NSData *)data{
//    // Skip `deflate` header (2 bytes) and checksum (4 bytes)
//    // validations and inflate raw deflated data.
//    NSRange range = NSMakeRange(2, data.length-4);
//    NSData *compressData = [data subdataWithRange:range];
//   
//    
//    NSMutableData* rData = [[NSMutableData alloc] initWithLength:[compressData length]*3];
//    rData.length = compression_decode_buffer(rData.mutableBytes, 1000000, compressData.bytes, [compressData length], nil, COMPRESSION_ZLIB);
//    if (rData.length <= 0) {
//        return nil;
//    }
//    return rData;
//}
- (NSData *)deflateDecompress:(NSData *)data {
    if (data.length < 8) return nil;

    const uint8_t *bytes = (const uint8_t *)data.bytes;

   
    if (bytes[0] != 0x78) {
       
        return nil;
    }

    NSUInteger payloadLength = data.length - 6;
    const uint8_t *payloadBytes = bytes + 2;

    uint32_t expectedChecksum;
    memcpy(&expectedChecksum, bytes + data.length - 4, sizeof(uint32_t));
    expectedChecksum = CFSwapInt32BigToHost(expectedChecksum);

    NSData *decompressedData = [self rawDecompress:payloadBytes
                                     payloadLength:payloadLength];
    if (!decompressedData) return nil;

    NSData *calculatedChecksumData = [FTDataCompression adler32:decompressedData];
    uint32_t calculatedChecksum;
    [calculatedChecksumData getBytes:&calculatedChecksum length:sizeof(uint32_t)];
    calculatedChecksum = CFSwapInt32BigToHost(calculatedChecksum);

    if (calculatedChecksum != expectedChecksum) {
        NSLog(@"Adler-32 checksum verification failed. Data may be corrupted.");
        return nil;
    }

    return decompressedData;
}
- (nullable NSData *)rawDecompress:(const uint8_t *)payload
                     payloadLength:(NSUInteger)payloadLength {
    if (payloadLength == 0) return nil;

    size_t bufferSize = payloadLength * 3;
    uint8_t *buffer = NULL;
    size_t decodedSize = 0;

    for (int i = 0; i < 4; i++) {
        buffer = malloc(bufferSize);
        if (!buffer) return nil;

        decodedSize = compression_decode_buffer(buffer, bufferSize,
                                               payload, payloadLength,
                                               NULL,
                                               COMPRESSION_ZLIB);

        if (decodedSize != 0) {
            return [NSData dataWithBytesNoCopy:buffer length:decodedSize freeWhenDone:YES];
        }

        free(buffer);
        buffer = NULL;
        bufferSize *= 4;
    }

    return nil;
}
@end
