//
//  NSDictionary+FTCopyProperties.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/5/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (FTCopyProperties)
- (NSDictionary *)ft_deepCopy;
- (BOOL)ft_hasValidValueForKey:(NSString *)key;
@end

@interface NSObject (FTSafeDictionary)
+ (NSDictionary *)ft_normalizedDictionaryWithObject:(nullable id)object;
@end

@interface FTLinePropertyBag : NSObject
@property (nonatomic, copy, readonly) NSDictionary *tags;
@property (nonatomic, copy, readonly) NSDictionary *fields;
@property (nonatomic, copy, readonly) NSDictionary *mergedDictionary;
- (instancetype)initWithTags:(nullable id)tags fields:(nullable id)fields;
- (FTLinePropertyBag *)bagByApplyingChangedValues:(nullable id)changedValues;
@end

NS_ASSUME_NONNULL_END
