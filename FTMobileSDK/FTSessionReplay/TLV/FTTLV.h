//
//  FTTLV.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/24.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
extern NSUInteger const FT_MAX_DATA_LENGTH;

NS_ASSUME_NONNULL_BEGIN

@interface FTTLV : NSObject
@property (nonatomic, assign) int16_t type;
@property (nonatomic, strong) NSData *value;
-(instancetype)initWithType:(int16_t)type value:(NSData *)value;
- (NSData *)serialize;
@end

NS_ASSUME_NONNULL_END
