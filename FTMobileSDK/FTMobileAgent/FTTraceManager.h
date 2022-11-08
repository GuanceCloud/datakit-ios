//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/11/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
DEPRECATED_ATTRIBUTE
@interface FTTraceManager : NSObject
+ (instancetype)sharedInstance DEPRECATED_ATTRIBUTE;

- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url DEPRECATED_MSG_ATTRIBUTE("已过时，请参考 FTExternalDataManager 类的 -getTraceHeaderWithKey 方法");
@end

NS_ASSUME_NONNULL_END
