//
//  FTViewTreeRecordingContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class FTSRContext,FTSRViewID,FTViewControllerContext;
@interface FTViewTreeRecordingContext : NSObject
@property (nonatomic, strong) FTSRContext *recorder;
@property (nonatomic, strong) FTSRViewID *viewIDGenerator;
@property (nonatomic, strong) id<UICoordinateSpace> coordinateSpace;
@property (nonatomic, strong) FTViewControllerContext *viewControllerContext;
@property (nonatomic, assign) CGRect clip;
@end

typedef NS_ENUM(NSUInteger,ViewControllerType){
    ViewControllerTypeAlert,
    ViewControllerTypeSafari,
    ViewControllerTypeActivity,
    ViewControllerTypeSwiftUI,
    ViewControllerTypeOther
};
@interface FTViewControllerContext : NSObject
@property (nonatomic, assign) BOOL isRootView;
@property (nonatomic, assign) ViewControllerType parentType;
- (BOOL)isRootView:(ViewControllerType)type;
- (NSString *)name;
- (void)setParentTypeWithViewController:(UIViewController *)viewController;
@end

NS_ASSUME_NONNULL_END
