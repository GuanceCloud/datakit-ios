//
//  FTErrorDataProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/10/12.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^ErrorMonitorInfoChangeBlock)(NSDictionary * _Nonnull);

@protocol FTErrorMonitorInfoWrapper <NSObject>

- (BOOL)enableMonitorMemory;
- (BOOL)enableMonitorCpu;
- (NSDictionary *)errorMonitorInfo;

@end

/// Add error data protocol
@protocol FTErrorDataDelegate <NSObject>
/// Add Error data
/// - Parameters:
///   - type: error type
///   - stateStr: app state
///   - message: error message
///   - stack: stack information
///   - property: property
///   - time: error date
- (void)addErrorWithType:(NSString *)type stateStr:(NSString *)stateStr message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property time:(long long)time;

@end


@protocol FTBacktraceReporting <NSObject>

- (NSString *)generateMainThreadBacktrace;

- (NSString *)generateAllThreadsBacktrace;
@end

@protocol FTDictionaryConvertible <NSObject>


- (nullable instancetype)initWithDict:(NSDictionary *)dict;

- (NSDictionary *)toDictionary;

@end
NS_ASSUME_NONNULL_END
