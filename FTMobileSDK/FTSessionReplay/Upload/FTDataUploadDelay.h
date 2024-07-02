//
//  FTDataUploadDelay.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/28.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTUploadPerformancePreset;
@interface FTDataUploadDelay : NSObject
@property (nonatomic, assign,readwrite) NSTimeInterval current;
-(instancetype)initWithPerformance:(id<FTUploadPerformancePreset>)performance;
- (void)increase;
- (void)decrease;
@end

NS_ASSUME_NONNULL_END
