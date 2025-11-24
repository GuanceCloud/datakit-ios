//
//  FTTraceContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/31.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Custom Trace content
@interface FTTraceContext: NSObject
/// traceId, used to associate with rum
@property (nonatomic, copy) NSString *traceId;
/// spanId, used to associate with rum
@property (nonatomic, copy) NSString *spanId;
/// trace data, SDK will add to request.allHTTPHeaderFields after receiving callback
@property (nonatomic, strong) NSDictionary<NSString*,NSString*>*traceHeader;

@end

NS_ASSUME_NONNULL_END
