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
@end

NS_ASSUME_NONNULL_END
