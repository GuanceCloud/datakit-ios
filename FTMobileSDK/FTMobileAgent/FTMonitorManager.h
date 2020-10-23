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
NS_ASSUME_NONNULL_BEGIN
@interface FTMonitorManager : NSObject
@property (nonatomic, strong) FTMobileConfig *config;
@property (nonatomic, strong) NSSet *netContentType;
/**
 * 获取 FTMonitorManager 单例
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;

-(void)setMobileConfig:(FTMobileConfig *)config;
/**
 * 设置 监控类型 可不设置直接获取 FTMobileAgent.config
*/
-(void)setMonitorType:(FTMonitorInfoType)type;
///**
// * 设置 监控上传周期
//*/
//-(void)setFlushInterval:(NSInteger)interval;
///**
// * 开启监控同步
//*/
//-(void)startFlush;
///**
// * 关闭监控同步
//*/
//-(void)stopFlush;
/**
 * 获取监控项的tag、field
*/
-(NSDictionary *)getMonitorTagFiledDict;
- (BOOL)trackUrl:(NSURL *)url;
- (void)trackUrl:(NSURL *)url completionHandler:(void (^)(BOOL track,BOOL sampled, FTNetworkTraceType type,NSString *skyStr))completionHandler;
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
