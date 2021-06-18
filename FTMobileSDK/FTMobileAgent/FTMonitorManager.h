//
//  FTMonitorManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTMobileConfig.h"
#import "FTConstants.h"
#import "FTRUMManger.h"
NS_ASSUME_NONNULL_BEGIN
@interface FTMonitorManager : NSObject
@property (nonatomic, strong) NSSet *netContentType;
@property (nonatomic, weak) id<FTRUMSessionResourceDelegate,FTRUMWebViewJSBridgeDataDelegate> sessionSourceDelegate;
@property (nonatomic, weak) id<FTRUMSessionErrorDelegate> sessionErrorDelegate;

/**
 * 获取 FTMonitorManager 单例
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;

-(void)setMobileConfig:(FTMobileConfig *)config;
-(void)setTraceConfig:(FTTraceConfig *)traceConfig;
-(void)setRumConfig:(FTRumConfig *)rumConfig;
- (BOOL)traceUrl:(NSURL *)url;
- (void)traceUrl:(NSURL *)url completionHandler:(void (^)(NSDictionary *traceHeader))completionHandler;
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
