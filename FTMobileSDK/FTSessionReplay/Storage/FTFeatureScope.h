//
//  FTFeatureScope.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTFeatureStorage.h"

NS_ASSUME_NONNULL_BEGIN

typedef FTTrackingConsent (^FTTrackingConsentProvider)(void);

@interface FTFeatureContext : NSObject
@property (nonatomic, assign, readonly) FTTrackingConsent trackingConsent;

- (instancetype)initWithTrackingConsent:(FTTrackingConsent)trackingConsent;

@end

typedef void (^FTFeatureWriteContext)(FTFeatureContext *context, id<FTWriter> writer);

@interface FTFeatureScope : NSObject
@property (nonatomic, assign, readonly) FTTrackingConsent trackingConsent;
@property (nonatomic, assign, readonly) BOOL isErrorSampled;

- (instancetype)initWithStorage:(FTFeatureStorage *)storage
        trackingConsentProvider:(FTTrackingConsentProvider)trackingConsentProvider;
- (void)updateTrackingConsent;
- (void)eventWriteContext:(FTFeatureWriteContext)block;
- (void)webViewEventWriteContext:(FTFeatureWriteContext)block;

@end

NS_ASSUME_NONNULL_END
