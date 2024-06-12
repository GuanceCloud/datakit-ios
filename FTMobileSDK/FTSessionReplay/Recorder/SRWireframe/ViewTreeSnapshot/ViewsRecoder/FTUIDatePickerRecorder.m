//
//  FTUIDatePickerRecorder.m
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/30.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTUIDatePickerRecorder.h"
#import "FTSRWireframe.h"
#import "FTViewAttributes.h"
#import "FTSRWireframesBuilder.h"
#import "FTSRUtils.h"
#import "FTSystemColors.h"
@interface FTUIDatePickerRecorder()
@property (nonatomic,copy,readwrite) NSString *identifier;

@end
@implementation FTUIDatePickerRecorder
-(instancetype)init{
    self = [super init];
    if(self){
        self.identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}
-(NSArray<id<FTSRWireframesBuilder>> *)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTRecorderContext *)context{
    if(![view isKindOfClass:UIDatePicker.class]){
        return nil;
    }
    if(!attributes.isVisible){
        return nil;
    }
    UIDatePicker *datePicker = (UIDatePicker *)view;
    if (@available(iOS 13.4, *)) {
        switch (datePicker.preferredDatePickerStyle) {
            case UIDatePickerStyleWheels:
                
                break;
            case UIDatePickerStyleCompact:
                
                break;
            case UIDatePickerStyleInline:
                
            default:
                
                break;
        }
    } else {
        
    }
    
    return nil;
}
@end

@implementation FTUIDatePickerBuilder

- ( NSArray<FTSRWireframe *> *)buildWireframes {
    FTSRShapeWireframe *wireframe = [[FTSRShapeWireframe alloc]initWithIdentifier:self.wireframeID frame:self.wireframeRect backgroundColor:self.isDisplayedInPopover?[FTSystemColors secondarySystemGroupedBackgroundColor]:[FTSystemColors systemBackgroundColor] cornerRadius:@(10) opacity:@(self.attributes.alpha)];
    wireframe.border = [[FTSRShapeBorder alloc]initWithColor:self.isDisplayedInPopover?[FTSystemColors secondarySystemFillColor]:nil width:1];
    return @[wireframe];
}

@end
