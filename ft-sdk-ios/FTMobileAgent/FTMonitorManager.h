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

NS_ASSUME_NONNULL_END
