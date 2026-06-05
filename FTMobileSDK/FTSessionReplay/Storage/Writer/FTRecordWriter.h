//
//  FTRecordWriter.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FTFeatureScope;

@interface FTRecordWriter : NSObject
@property (nonatomic, assign, readonly) BOOL isErrorSampled;

- (instancetype)initWithFeatureScope:(FTFeatureScope *)featureScope;
- (void)write:(NSData *)data;
- (void)write:(NSData *)data forceNewFile:(BOOL)force;

@end

NS_ASSUME_NONNULL_END
