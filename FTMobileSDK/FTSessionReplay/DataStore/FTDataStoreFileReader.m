//
//  FTDataStoreFileReader.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/1.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDataStoreFileReader.h"
#import "FTDataStore.h"
#import "FTTLVReader.h"
#import "FTFile.h"
#import "FTTLV.h"
@interface FTDataStoreFileReadingError:NSError
+ (NSError *)unexpectedBlocks;
+ (NSError *)unexpectedBlocksOrder;
@end
@implementation FTDataStoreFileReadingError
+ (NSError *)unexpectedBlocks{
    NSError *error = [NSError errorWithDomain:@"com.guance.data-store-file-reader" code:-100 userInfo:@{NSLocalizedDescriptionKey:@"unexpected blocks"}];
    return error;
}
+ (NSError *)unexpectedBlocksOrder{
    NSError *error = [NSError errorWithDomain:@"com.guance.data-store-file-reader" code:-101 userInfo:@{NSLocalizedDescriptionKey:@"unexpected blocks order"}];
    return error;
}
@end

@interface FTDataStoreFileReader()
@property (nonatomic, strong) FTFile *file;
@end
@implementation FTDataStoreFileReader
-(instancetype)initWithFile:(FTFile *)file{
    self = [super init];
    if(self){
        _file = file;
    }
    return self;
}
- (void)read:(DataStoreValueResult)callback{
    FTTLVReader *reader = [[FTTLVReader alloc]initWithStream:self.file.stream maxDataLength:FT_MAX_DATA_LENGTH];
    NSArray<FTTLV*> *tlvs = [reader all];
    if(tlvs.count!=2){
        callback([FTDataStoreFileReadingError unexpectedBlocks],nil,-1);
    }
    if([tlvs firstObject].type != DataStoreBlockTypeVersion || [tlvs lastObject].type != DataStoreBlockTypeData ){
        callback([FTDataStoreFileReadingError unexpectedBlocksOrder],nil,-1);
    }
    NSData *versionData = [tlvs firstObject].value;
    if(versionData.length>=sizeof(FTDataStoreKeyVersion)){
        FTDataStoreKeyVersion version = 0;
        [versionData getBytes:&version length:versionData.length];
        NSData *data = [tlvs lastObject].value;
        callback(nil,data,version);
    }
}
@end
