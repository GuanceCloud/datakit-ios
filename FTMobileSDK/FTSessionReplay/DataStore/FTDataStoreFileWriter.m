//
//  FTDataStoreFileWriter.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/2.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTDataStoreFileWriter.h"
#import "FTFile.h"
#import "FTDataStore.h"
#import "FTTLV.h"
@interface FTDataStoreFileWriter()
@property (nonatomic, strong) FTFile *file;
@end
@implementation FTDataStoreFileWriter
-(instancetype)initWithFile:(FTFile *)file{
    self = [super init];
    if(self){
        _file = file;
    }
    return self;
}
- (void)write:(NSData *)data version:(FTDataStoreKeyVersion)version{
    NSData *typeData = [NSData dataWithBytes:&version length:sizeof(version)];
    FTTLV *versionTLV = [[FTTLV alloc]initWithType:DataStoreBlockTypeVersion value:typeData];
    FTTLV *dataTLV = [[FTTLV alloc]initWithType:DataStoreBlockTypeData value:data];
    NSMutableData *encoded = [[NSMutableData alloc]init];
    
    NSData *versionSerialize = [versionTLV serialize];
    if(versionSerialize){
        [encoded appendData:versionSerialize];
    }else{
        return;
    }
    NSData *dataSerialize = [dataTLV serialize];
    if(dataSerialize){
        [encoded appendData:dataSerialize];
    }else{
        return;
    }
    [self.file write:encoded];
}
@end
