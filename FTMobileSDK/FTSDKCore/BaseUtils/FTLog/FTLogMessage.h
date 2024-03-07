//
//  FTLogMessage.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTLog+Private.h"
#import "FTEnumConstant.h"
NS_ASSUME_NONNULL_BEGIN


@interface FTLogMessage : NSObject
@property (nonatomic, copy, readonly) NSString *message;
@property (nonatomic, assign, readonly) LogStatus level;
@property (nonatomic, copy, readonly) NSString *function;
@property (nonatomic, assign, readonly) NSUInteger line;
@property (nonatomic, strong, readonly) NSDate *timestamp;
@property (nonatomic, assign) BOOL userLog;
@property (nonatomic, strong, readonly) NSDictionary *property;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithMessage:(NSString *)message
                          level:(LogStatus)level
                       function:(NSString *)function
                           line:(NSUInteger)line
                      timestamp:(NSDate *)timestamp;
- (instancetype)initWithMessage:(NSString *)message
                          level:(LogStatus)level
                       property:(nullable NSDictionary *)property
                      timestamp:(NSDate *)timestamp;
@end

NS_ASSUME_NONNULL_END
