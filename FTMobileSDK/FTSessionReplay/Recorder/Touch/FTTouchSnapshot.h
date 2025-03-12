//
//  FTTouchSnapshot.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/9/5.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger,FTTouchPhase) {
    TouchDown,
    TouchMoved,
    TouchUp
};

@interface FTTouchCircle : NSObject
@property (nonatomic, assign) CGPoint position;
@property (nonatomic, assign) FTTouchPhase phase;
@property (nonatomic, assign) int identifier;
@property (nonatomic, assign) long long timestamp;
@property (nonatomic, strong ,nullable) NSNumber *touchPrivacyOverride;
@end

@interface FTTouchSnapshot : NSObject

@property (nonatomic, assign) long long timestamp;
@property (nonatomic, strong) NSArray<FTTouchCircle*> *touches;
- (instancetype)initWithTouches:(NSArray<FTTouchCircle*> *)touches;

@end

NS_ASSUME_NONNULL_END
