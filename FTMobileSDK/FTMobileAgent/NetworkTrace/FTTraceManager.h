//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTTraceHandler;
@interface FTTraceManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isTraceUrl:(NSURL *)url;

- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;

- (FTTraceHandler *)getTraceHandler:(NSString *)key;
- (void)removeTraceHandlerWithKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
