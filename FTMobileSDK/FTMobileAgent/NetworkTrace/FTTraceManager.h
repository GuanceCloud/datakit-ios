//
//  FTTraceManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/3/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef BOOL(^FTIntakeUrl)(NSURL *url);

@class FTTraceHandler;
@interface FTTraceManager : NSObject
@property (nonatomic, assign) BOOL enableAutoTrace;
@property (nonatomic, copy ,nullable) FTIntakeUrl intakeUrl;

+ (instancetype)sharedInstance;
- (BOOL)isTraceUrl:(NSURL *)url;

- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;

- (nullable FTTraceHandler *)getTraceHandler:(NSString *)key;
- (void)removeTraceHandlerWithKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
