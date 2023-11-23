//
//  FTURLSessionInterceptor+Private.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/11/23.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTURLSessionInterceptor.h"
#import "FTURLSessionInterceptorProtocol.h"
#import "FTTracerProtocol.h"
#import "FTExternalResourceProtocol.h"
#import "FTTracerProtocol.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTURLSessionInterceptor ()<FTURLSessionInterceptorProtocol,FTExternalResourceProtocol>
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
