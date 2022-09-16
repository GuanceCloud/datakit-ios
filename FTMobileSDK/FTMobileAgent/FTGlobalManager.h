//
//  FTGlobalManager.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/6.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "URLSessionAutoInstrumentation.h"
#import "FTMobileConfig.h"
#import "FTTracerProtocol.h"

NS_ASSUME_NONNULL_BEGIN
// 通过遵循的协议 管理全局的功能点
@interface FTGlobalManager : NSObject
@property (nonatomic, strong) FTRumConfig *rumConfig;
@property (nonatomic, strong) FTTraceConfig *traceConfig;
@property (nonatomic, weak) URLSessionAutoInstrumentation *sessionInstrumentation;
@property (nonatomic, weak) id<FTTracerProtocol> tracer;
+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
