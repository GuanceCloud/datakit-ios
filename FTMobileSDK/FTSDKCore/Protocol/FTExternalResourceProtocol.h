//
//  FTExternalResourceProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/11/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRumResourceProtocol.h"
NS_ASSUME_NONNULL_BEGIN

/// Protocol for handling user-defined HTTP Resource data processing
@protocol FTExternalResourceProtocol <NSObject,FTRumResourceProtocol>
/// Get request headers needed for trace
/// - Parameters:
///   - key: Request identifier
///   - url: Request URL
- (nullable NSDictionary *)getTraceHeaderWithUrl:(NSURL *)url;

/// Get request headers needed for trace
/// - Parameters:
///   - key: Request identifier
///   - url: Request URL
- (nullable NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
