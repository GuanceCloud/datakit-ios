//
//  FTJSONKeyMapper.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/22.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NSString *_Nullable(^FTJSONModelKeyMapBlock)(NSString *keyName);

@interface FTJSONKeyMapper : NSObject
@property (readonly, nonatomic) FTJSONModelKeyMapBlock modelToJSONKeyBlock;
- (instancetype)initWithModelToJSONDictionary:(NSDictionary <NSString *, NSString *> *)toJSON;
- (NSString *)convertValue:(NSString *)value;
@end

NS_ASSUME_NONNULL_END
