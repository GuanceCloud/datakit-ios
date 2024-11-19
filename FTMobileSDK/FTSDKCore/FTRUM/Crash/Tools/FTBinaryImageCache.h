//
//  FTBinaryImageCache.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface FTBinaryImageInfo : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, copy) NSString *UUID;
@property (nonatomic) uint64_t vmAddress;
@property (nonatomic) uint64_t address;
@property (nonatomic) uint64_t size;

@end
@interface FTBinaryImageCache : NSObject
- (void)start;

- (void)stop;

- (nullable FTBinaryImageInfo *)imageByAddress:(const uint64_t)address;

+ (NSString *_Nullable)convertUUID:(const unsigned char *const)value;
@end

NS_ASSUME_NONNULL_END
