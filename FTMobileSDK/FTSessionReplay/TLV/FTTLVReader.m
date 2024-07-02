//
//  FTTLVReader.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/24.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTTLVReader.h"
#import "FTTLV.h"

@interface FTTLVReader()
@property (nonatomic, strong) NSInputStream *stream;
@property (nonatomic, assign) NSUInteger maxDataLength;
@end
@implementation FTTLVReader
-(instancetype)initWithStream:(NSInputStream *)stream{
    return [self initWithStream:stream maxDataLength:FT_MAX_DATA_LENGTH];
}
-(instancetype)initWithStream:(NSInputStream *)stream maxDataLength:(NSUInteger)length{
    self = [super init];
    if(self){
        _stream = stream;
        _maxDataLength = length;
        [_stream open];
    }
    return self;
}
- (NSArray<FTTLV*> *)all{
    NSMutableArray *array = [NSMutableArray new];
    FTTLV *tlv = [self next];
    while (tlv != nil) {
        [array addObject:tlv];
        tlv = [self next];
    }
    return array;
}
- (FTTLV *)next{
    int typeSize = sizeof(uint16_t);
    int lengthSize = sizeof(int32_t);
    NSData *typeData = [self read:typeSize];
    NSData *dataLength = [self read:lengthSize];
    if(typeData && dataLength){
        NSUInteger length = 0;
        [dataLength getBytes:&length length:dataLength.length];
        NSData *data = [self read:length];
        if(data){
            FTTLV *tlv = [[FTTLV alloc]init];
            NSUInteger type = 0;
            [typeData getBytes:&type length:typeData.length];
            tlv.type = type;
            tlv.value = data;
            return tlv;
        }
    }
    return nil;
}
- (NSData *)read:(NSUInteger)length{
    if(length>0){
        NSMutableData *data = [NSMutableData dataWithLength:length];
        const void *bytes = [data bytes];
        if (bytes) {
            UInt8 *uint8Bytes = (UInt8 *)bytes;
            NSInteger count = [self.stream read:uint8Bytes maxLength:length];
            if(count == length){
                return data;
            }
        }
    }
    return nil;
}
-(void)dealloc{
    [_stream close];
}
@end
