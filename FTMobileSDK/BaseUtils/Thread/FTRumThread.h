//
//  FTRumThread.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/20.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTRumThread : NSThread
@property (nonatomic, strong, readonly) NSRunLoop *runLoop;

+ (instancetype)sharedThread;
@end

NS_ASSUME_NONNULL_END
