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
    
    NSData *rowData = [FTDataCompression rowCompress:data];
    
    uint8_t nbytes[] = {0x63, 0x00, 0x00};
    NSData *eData = [NSData dataWithBytes:nbytes length:sizeof(nbytes)];
    
    // Then
    XCTAssertTrue([rowData isEqualToData:eData]);
}
- (void)testDataCompression_deflate_big_data{
    NSDictionary *dict = @{@"a":@"123456",
                           @"b":@"234567"
    };
    FTJSONUtil *util = [FTJSONUtil new];
    NSData *jsonData = [util JSONSerializeDictObject:dict];
    
    NSData *compressionData = [FTDataCompression deflate:jsonData];

    XCTAssertTrue(compressionData.length<jsonData.length);
}
- (void)testDataCompression_deflate_CalculatesAdler32{
    NSData *data = [@"Wikipedia" dataUsingEncoding:NSUTF8StringEncoding];
    UInt32 uint32Value = [FTDataCompression adler32:data];
    
    // From https://en.wikipedia.org/wiki/Adler-32
    XCTAssertEqual(uint32Value, 300286872);

}
- (void)testDataCompression_deflate_format{
    NSDictionary *dict = @{@"a":@"123456",
                           @"b":@"234567",
                           @"c":@"qwertyuii"
    };
    FTJSONUtil *util = [FTJSONUtil new];
    NSData *jsonData = [util JSONSerializeDictObject:dict];
    
    NSData *compressionData = [FTDataCompression deflate:jsonData];
    
    NSData *data = [self deflateDecompress:compressionData];
    
    NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    
    NSDictionary *nDict = [FTJSONUtil dictionaryWithJsonString:str];
    XCTAssertTrue([dict isEqualToDictionary:nDict]);
}

- (NSData *)deflateDecompress:(NSData *)data{
    // Skip `deflate` header (2 bytes) and checksum (4 bytes)
    // validations and inflate raw deflated data.
    NSRange range = NSMakeRange(2, data.length-4);
    NSData *compressData = [data subdataWithRange:range];
   
    
    NSMutableData* rData = [[NSMutableData alloc] initWithLength:[compressData length]*3];
    rData.length = compression_decode_buffer(rData.mutableBytes, 1000000, compressData.bytes, [compressData length], nil, COMPRESSION_ZLIB);
    if (rData.length <= 0) {
        return nil;
    }
    return rData;
}
@end
