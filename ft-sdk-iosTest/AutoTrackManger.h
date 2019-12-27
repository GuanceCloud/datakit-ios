//
//  AutoTrackManger.h
//  ft-sdk-iosTest
//
//  Created by 胡蕾蕾 on 2019/12/27.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoTrackManger : NSObject
+(AutoTrackManger *)sharedManger;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (id)copy NS_UNAVAILABLE; // 没有遵循协议可以不写
- (id)mutableCopy NS_UNAVAILABLE; // 没有遵循协议可以不写
- (void)addAutoTrackViewScreenCount;
- (void)addAutoTrackClickCount;
- (void)addTrackCount;
- (NSArray *)getEndResult;
@end

NS_ASSUME_NONNULL_END
