//
//  FTResourceWriter.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTResourceWriter.h"
#import "FTSRRecord.h"
#import "FTFileWriter.h"
#import <pthread.h>
#import "FTFeatureDataStore.h"
#import "FTLog+Private.h"

NSString *const FT_StoreCreationKey = @"ft-store-creation";
NSString *const FT_KnownResourcesKey = @"ft-known-resources";
@interface FTResourceWriter()
//TODO: dataStore 读取数据 callback 回调是在读写线程里，所以需要加锁
@property (nonatomic, strong) NSMutableSet *knownIdentifiers;
@property (nonatomic, strong) FTFeatureDataStore *dataStore;
@property (nonatomic, assign) NSTimeInterval dataStoreResetTime;
@end
@implementation FTResourceWriter

- (instancetype)initWithWriter:(id<FTWriter>)writer dataStore:(id<FTDataStore>)dataStore{
    self = [super init];
    if(self){
        _writer = writer;
        _knownIdentifiers = [[NSMutableSet alloc]init];
        _dataStore = dataStore;
        _dataStoreResetTime = 30*24*60*60;//30 day
        [self readKnownIdentifiers];
    }
    return self;
}
- (void)readKnownIdentifiers{
    __weak typeof(self) weakSelf = self;
    [self.dataStore valueForKey:FT_StoreCreationKey callback:^(NSError *error, NSData *data, FTDataStoreKeyVersion version) {
        if(!error){
            if(version == DataStoreDefaultKeyVersion && ([[NSDate date] timeIntervalSince1970] - [weakSelf transDataAsTimeInterval:data] < weakSelf.dataStoreResetTime)){
                    [weakSelf.dataStore valueForKey:FT_KnownResourcesKey callback:^(NSError *error, NSData *data, FTDataStoreKeyVersion version) {
                        if(!error){
                            if(version != DataStoreDefaultKeyVersion){
                                FTInnerLogError(@"[Session Replay] Resource Writer Read KnownIdentifiers Error");
                            }else if(data!=nil){
                                NSError *error;
                                NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                if(array){
                                    [weakSelf.knownIdentifiers addObjectsFromArray:array];
                                }
                            }
                        }else{
                            FTInnerLogError(@"[Session Replay] Resource Writer Read KnownIdentifiers Error: %@",error.localizedDescription);
                        }
                    }];
            }else{
                [weakSelf.dataStore setValue:[weakSelf transTimeIntervalAsData:[[NSDate date] timeIntervalSince1970]] forKey:FT_StoreCreationKey version:DataStoreDefaultKeyVersion];
                [weakSelf.dataStore removeValueForKey:FT_KnownResourcesKey];
            }
        }else{
            FTInnerLogError(@"[Session Replay] Resource Writer Error: %@",error.localizedDescription);
        }
    }];
}
- (void)write:(NSArray<FTEnrichedResource*>*)resources{
    NSMutableSet *unknownResources = [NSMutableSet new];
    [resources enumerateObjectsUsingBlock:^(FTEnrichedResource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(![self.knownIdentifiers containsObject:obj.identifier]){
            [self.writer write:[obj toJSONData]];
            [unknownResources addObject:obj.identifier];
        }
    }];
    if(unknownResources.count>0){
        [self.knownIdentifiers unionSet:unknownResources];
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:[self.knownIdentifiers allObjects] options:0 error:&error];
        if(data){
            [self.dataStore setValue:data forKey:FT_KnownResourcesKey version:DataStoreDefaultKeyVersion];
        }
    }
}
- (NSTimeInterval)transDataAsTimeInterval:(NSData *)data{
    NSTimeInterval timeInterval = 0;
    if(data.length>=sizeof(NSTimeInterval)){
        [data getBytes:&timeInterval length:data.length];
    }
    return timeInterval;
}
- (NSData *)transTimeIntervalAsData:(NSTimeInterval)timeInterval{
    return [NSData dataWithBytes:&timeInterval length:sizeof(timeInterval)];
}
@end
