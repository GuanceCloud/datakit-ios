//
//  FTTaskInterceptionModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/27.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTTaskInterceptionModel : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, strong) NSURLSessionTaskMetrics *metrics;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSURLSessionTask *task;
/**
 * trace 开启 enableLinkRumData时 resource Tags 添加 trace_id、span_id
 */
@property (nonatomic, strong) NSDictionary *linkTags;
@end

NS_ASSUME_NONNULL_END
