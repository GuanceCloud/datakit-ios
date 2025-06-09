//
//  FTDataUploadWorker.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTUploadProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@class FTHTTPClient;
@interface FTDataUploadWorker : NSObject
@property (nonatomic, weak) id<FTUploadCountProtocol> counter;
@property (nonatomic, weak) id<FTSessionOnErrorDataHandler> errorSampledConsume;
@property (nonatomic, strong) FTHTTPClient *httpClient;

-(instancetype)initWithSyncPageSize:(int)syncPageSize
                      syncSleepTime:(int)syncSleepTime;

-(void)flushWithSleep:(BOOL)withSleep;

-(void)cancelSynchronously;
-(void)cancelAsynchronously;
-(void)updateWithRemoteConfiguration:(NSDictionary *)configuration;
@end

NS_ASSUME_NONNULL_END
