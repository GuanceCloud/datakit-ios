//
//  FTErrorDataProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/10/12.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>

/// Add error data protocol
@protocol FTErrorDataDelegate <NSObject>
/// Add Error data
/// - Parameters:
///   - type: error type
///   - message: error message
///   - stack: stack information
- (void)internalErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
@end


@protocol FTBacktraceReporting <NSObject>

- (NSString *)generateMainThreadBacktrace;

@end
