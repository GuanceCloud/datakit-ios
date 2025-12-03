//
//  FTWKWebViewRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/18.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//
#if !TARGET_OS_TV
#import <Foundation/Foundation.h>
#import "FTSRNodeWireframesBuilder.h"

NS_ASSUME_NONNULL_BEGIN
@class FTViewAttributes;

@interface FTWKWebViewBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, assign) int64_t slotID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, strong, nullable) NSDictionary *linkRUMKeysInfo;
@end

@interface FTWKWebViewRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

NS_ASSUME_NONNULL_END
#endif
