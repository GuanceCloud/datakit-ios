//
//  FTTouchSnapshot.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/12/27.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger,FTTouchState) {
    TouchDown,
    TouchMoved,
    TouchUp
};

@interface FTTouchCircle : NSObject
@property (nonatomic, assign) float width;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) FTTouchState state;
@property (nonatomic, assign) int identifier;
@property (nonatomic, assign) long long timestamp;
@end

NS_ASSUME_NONNULL_END
