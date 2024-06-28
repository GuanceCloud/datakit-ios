//
//  FTReader.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/26.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTReader.h"
#import "FTTLV.h"
@implementation FTBatch
-(instancetype)initWithFile:(id<FTReadableFile>)file datas:(NSArray<FTTLV*> *)datas{
    self = [super init];
    if(self){
        _file = file;
        _tlvDatas = datas;
    }
    return self;
}
- (NSArray *)events{
    NSMutableArray *arrays = [[NSMutableArray alloc]init];
    for (FTTLV *tlv in self.tlvDatas) {
        [arrays addObject:tlv.value];
    }
    return arrays;
}
@end
