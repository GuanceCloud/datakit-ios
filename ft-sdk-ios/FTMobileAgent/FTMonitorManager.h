//
//  FTMonitorManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN


@class FTMobileConfig;

@interface FTMonitorManager : NSObject
-(instancetype)initWithConfig:(FTMobileConfig *)config;
-(void)flush;
-(NSDictionary *)getMonitorTagFiledDict;
@end
@interface FTTaskMetrics : NSObject
@property (nonatomic, assign) NSTimeInterval tcpTime;
@property (nonatomic, assign) NSTimeInterval dnsTime;
@property (nonatomic, assign) NSTimeInterval responseTime;
@end
NS_ASSUME_NONNULL_END
