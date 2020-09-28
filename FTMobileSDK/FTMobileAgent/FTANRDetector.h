//
//  FTANRMonitor.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/9/28.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTANRDetectorDelegate <NSObject>
- (void)onMainThreadSlowStackDetected:(NSArray*)slowStack;
@end
@interface FTANRDetector : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, weak) id<FTANRDetectorDelegate> watchDelegate;


//must be called from main thread
- (void)startDetecting;
- (void)stopDetecting;

@end

NS_ASSUME_NONNULL_END
