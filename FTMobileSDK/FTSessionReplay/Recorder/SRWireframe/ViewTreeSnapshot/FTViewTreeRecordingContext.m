//
//  FTViewTreeRecordingContext.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTViewTreeRecordingContext.h"
#import <SafariServices/SafariServices.h>
#import <SwiftUI/SwiftUI.h>
@implementation FTViewTreeRecordingContext
- (instancetype)copyWithZone:(NSZone *)zone {
    FTViewTreeRecordingContext *options = [[[self class] allocWithZone:zone] init];
    options.recorder = self.recorder;
    options.viewIDGenerator = self.viewIDGenerator;
    options.coordinateSpace = self.coordinateSpace;
    options.viewControllerContext = self.viewControllerContext;
    options.clip = self.clip;
    return options;
}
@end
@implementation FTViewControllerContext
- (NSString *)name{
    if(!self.isRootView){
        return nil;
    }
    switch (self.parentType) {
        case ViewControllerTypeAlert:
            return @"Alert";
        case ViewControllerTypeSafari:
            return @"Safari";
        case ViewControllerTypeActivity:
            return @"Activity";
        case ViewControllerTypeSwiftUI:
            return @"SwiftUI";
        case ViewControllerTypeOther:
            return nil;
    }
}
- (BOOL)isRootView:(ViewControllerType)type {
    return self.parentType == type && self.isRootView == YES;
}
- (void)setParentTypeWithViewController:(UIViewController *)viewController{
    if([viewController isKindOfClass:UIAlertController.class]){
        self.parentType = ViewControllerTypeAlert;
    }else if ([viewController isKindOfClass:UIActivityViewController.class]){
        self.parentType = ViewControllerTypeActivity;
    }else if ([viewController isKindOfClass:SFSafariViewController.class]){
        self.parentType = ViewControllerTypeSafari;
    }else if([viewController isKindOfClass:NSClassFromString(@"UIHostingController")]){
        self.parentType = ViewControllerTypeSwiftUI;
    }else{
        self.parentType = ViewControllerTypeOther;
    }
}
@end
