//
//  FTAutoInterceptorProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/10/27.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#ifndef FTAutoInterceptorProtocol_h
#define FTAutoInterceptorProtocol_h
#import "FTURLSessionInterceptorProtocol.h"

@protocol FTAutoInterceptorProtocol<NSObject>
@property (nonatomic, weak ,readonly) id<FTURLSessionInterceptorProtocol> interceptor;
/// Set whether to support automatic collection of rum resource data
@property (nonatomic, assign) BOOL enableAutoRumTrack;
/// Implement trace functionality, add trace parameters to request header
/// - Parameter request: HTTP initial request
- (NSURLRequest *)interceptRequest:(NSURLRequest *)request;

/// Determine whether URL should be collected
/// Whether it's an SDK internal upload link
/// - Parameter url: URL to be determined
- (BOOL)isNotSDKInsideUrl:(NSURL *)url;
@end
#endif /* FTAutoInterceptorProtocol_h */
