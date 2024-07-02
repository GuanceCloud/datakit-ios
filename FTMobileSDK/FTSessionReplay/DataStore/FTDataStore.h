//
//  FTDataStore.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/1.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTDataStore_h
#define FTDataStore_h
typedef uint16_t FTDataStoreKeyVersion;

// 保存的数据,数据结构发生变化时，更新该常量，用于区分新旧数据，可对旧数据做兼容或直接删除
static FTDataStoreKeyVersion const DataStoreDefaultKeyVersion = 0;

typedef NS_ENUM(uint16_t,DataStoreBlockType) {
    DataStoreBlockTypeVersion = 0x00,
    DataStoreBlockTypeData = 0X01,
};

typedef void (^DataStoreValueResult)(NSError *error,NSData *data,FTDataStoreKeyVersion version);
@protocol FTDataStore <NSObject>
- (void)setValue:(NSData*)value forKey:(NSString *)key version:(FTDataStoreKeyVersion)version;
- (void)removeValueForKey:(NSString *)key;
- (void)valueForKey:(NSString *)key callback:(DataStoreValueResult)callback;
@end

#endif /* FTDataStore_h */
