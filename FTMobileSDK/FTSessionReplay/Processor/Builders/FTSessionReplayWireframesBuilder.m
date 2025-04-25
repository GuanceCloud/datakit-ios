//
//  FTSessionReplayWireframesBuilder.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/21.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTSessionReplayWireframesBuilder.h"
#import "FTSRWireframe.h"
#import "FTSRUtils.h"
#import "FTViewAttributes.h"
@interface FTSessionReplayWireframesBuilder()
@property (nonatomic, strong) NSArray<id<FTSRResource>> *resources;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *webViewSlotIDs;
@end
@implementation FTSessionReplayWireframesBuilder
-(instancetype)initWithResources:(NSArray<id <FTSRResource>>*)resources webViewSlotIDs:( NSSet<NSNumber *> *)webViewSlotIDs{
    self = [super init];
    if (self) {
        _resources = resources;
        _webViewSlotIDs = [NSMutableSet setWithSet:webViewSlotIDs];
    }
    return self;
}
- (FTSRWireframe *)createShapeWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes{
    return [[FTSRShapeWireframe alloc]initWithIdentifier:identifier attributes:attributes];
}
- (FTSRShapeBorder *)createShapeBorderWithColor:(nullable CGColorRef)color width:(CGFloat)width {
    if (!color || width<=0) return nil;
    return [[FTSRShapeBorder alloc] initWithColor:[FTSRUtils colorHexString:color] width:width];
}
- (FTSRWireframe *)visibleWebViewWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes{
    FTSRWebViewWireframe *wireframe = [[FTSRWebViewWireframe alloc]initWithIdentifier:identifier frame:attributes.frame];
    wireframe.clip = [[FTSRContentClip alloc]initWithFrame:attributes.frame clip:attributes.clip];
    wireframe.slotId = [NSString stringWithFormat:@"%lld",identifier];
    wireframe.isVisible = YES;
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:attributes.backgroundColor.CGColor] cornerRadius:@(attributes.layerCornerRadius) opacity:@(attributes.alpha)];
    [self.webViewSlotIDs removeObject:@(identifier)];
    return wireframe;
}
- (NSArray <FTSRWireframe*> *)hiddenWebViewWireframes{
    if (self.webViewSlotIDs.count == 0) {
        return @[];
    }
    NSMutableArray *array = [NSMutableArray new];
    [self.webViewSlotIDs enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
        FTSRWebViewWireframe *wireframe = [[FTSRWebViewWireframe alloc]initWithIdentifier:[obj longLongValue] frame:CGRectZero];
        wireframe.slotId = [NSString stringWithFormat:@"%@",obj];
        [array addObject:wireframe];
    }];
    [self.webViewSlotIDs removeAllObjects];
    return array;
}
@end


