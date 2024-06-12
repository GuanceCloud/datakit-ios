//
//  FTSessionReplayUploader.h
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/11.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
extern NSString * const FT_SESSION_REPLAY_INFO_PLIST;

@interface FTSessionReplayUploader : NSObject
@property (nonatomic, assign) NSInteger onceUploadCount;
@property (nonatomic, strong) NSDictionary *baseProperty;
@property (nonatomic, copy) NSString *currentViewid;
-(void)flushSessionReplay;
@end

NS_ASSUME_NONNULL_END
