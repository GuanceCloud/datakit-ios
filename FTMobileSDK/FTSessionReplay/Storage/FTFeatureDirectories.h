//
//  FTFeatureDirectories.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FTDirectory;
NS_ASSUME_NONNULL_BEGIN

@interface FTFeatureDirectories : NSObject
@property (nonatomic, strong, readonly) FTDirectory *granted;
@property (nonatomic, strong, readonly, nullable) FTDirectory *pending;
@property (nonatomic, strong, readonly, nullable) FTDirectory *errorSampled;

- (instancetype)initWithGranted:(FTDirectory *)granted
                        pending:(nullable FTDirectory *)pending
                   errorSampled:(nullable FTDirectory *)errorSampled;
@end

NS_ASSUME_NONNULL_END
