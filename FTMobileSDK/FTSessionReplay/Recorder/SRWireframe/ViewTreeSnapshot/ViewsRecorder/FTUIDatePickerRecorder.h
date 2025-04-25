//
//  FTUIDatePickerRecorder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTSRNodeWireframesBuilder.h"

@class FTViewAttributes,FTViewTreeRecorder;
NS_ASSUME_NONNULL_BEGIN
@interface FTUIDatePickerBuilder : NSObject<FTSRNodeWireframesBuilder>
@property (nonatomic, assign) int64_t wireframeID;
@property (nonatomic, strong) FTViewAttributes *attributes;
@property (nonatomic, assign) CGRect wireframeRect;
@property (nonatomic, assign) BOOL isDisplayedInPopover;
@end
@interface FTUIDatePickerRecorder : NSObject<FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
-(instancetype)initWithIdentifier:(NSString *)identifier;
@end
@interface FTWheelsStyleDatePickerRecorder : NSObject
-(instancetype)initWithIdentifier:(NSString *)identifier;
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources;
@end
@interface FTInlineStyleDatePickerRecorder : NSObject
-(instancetype)initWithIdentifier:(NSString *)identifier;
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources;
@end

@interface FTCompactStyleDatePickerRecorder : NSObject
-(instancetype)initWithIdentifier:(NSString *)identifier;
-(void)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context nodes:(NSMutableArray *)nodes resources:(NSMutableArray *)resources;
@end
NS_ASSUME_NONNULL_END
