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
@property (nonatomic, strong) NSMutableSet<NSNumber *> *webViewSlotIDs;
@property (nonatomic, strong) NSMutableDictionary *linkRUMKeysInfo;
@end
@implementation FTSessionReplayWireframesBuilder
-(instancetype)initWithResources:(NSArray<id <FTSRResource>>*)resources webViewSlotIDs:( NSSet<NSNumber *> *)webViewSlotIDs{
    self = [super init];
    if (self) {
        _resources = resources ? [NSMutableArray arrayWithArray:resources]: [NSMutableArray new];
        _webViewSlotIDs = [NSMutableSet setWithSet:webViewSlotIDs];
        _linkRUMKeysInfo = [NSMutableDictionary new];
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
- (FTSRWebViewWireframe *)visibleWebViewWireframeWithID:(int64_t)identifier attributes:(FTViewAttributes *)attributes linkRUMKeysInfo:(nullable NSDictionary *)linkRUMKeysInfo{
    FTSRWebViewWireframe *wireframe = [[FTSRWebViewWireframe alloc]initWithIdentifier:identifier frame:attributes.frame];
    wireframe.clip = [[FTSRContentClip alloc]initWithFrame:attributes.frame clip:attributes.clip];
    wireframe.slotId = [NSString stringWithFormat:@"%lld",identifier];
    wireframe.isVisible = @(YES);
    wireframe.shapeStyle = [[FTSRShapeStyle alloc]initWithBackgroundColor:[FTSRUtils colorHexString:attributes.backgroundColor.CGColor] cornerRadius:@(attributes.layerCornerRadius) opacity:@(attributes.alpha)];
    [self.webViewSlotIDs removeObject:@(identifier)];
    if (linkRUMKeysInfo.count>0) {
        [self.linkRUMKeysInfo addEntriesFromDictionary:linkRUMKeysInfo];
    }
    return wireframe;
}

- (FTSRImageWireframe *)createImageWireframeWithID:(int64_t)identifier resource:(id<FTSRResource>)resource frame:(CGRect)frame clip:(CGRect)clip{
    FTSRImageWireframe *imageWireframe = [[FTSRImageWireframe alloc]initWithIdentifier:identifier frame:frame];
    imageWireframe.resourceId = [resource calculateIdentifier];
    imageWireframe.clip = [[FTSRContentClip alloc]initWithFrame:frame clip:clip];
    [self.resources addObject:resource];
    return imageWireframe;
}
- (void)addResources:(NSArray<id <FTSRResource>>*)resources{
    if (resources && resources.count>0) {
        [self.resources addObjectsFromArray:resources];
    }
}
- (NSArray <FTSRWireframe*> *)hiddenWebViewWireframes{
    if (self.webViewSlotIDs.count == 0) {
        return @[];
    }
    NSMutableArray *array = [NSMutableArray new];
    [self.webViewSlotIDs enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
        FTSRWebViewWireframe *wireframe = [[FTSRWebViewWireframe alloc]initWithIdentifier:[obj longLongValue] frame:CGRectZero];
        wireframe.isVisible = @(NO);
        wireframe.slotId = [NSString stringWithFormat:@"%@",obj];
        [array addObject:wireframe];
    }];
    [self.webViewSlotIDs removeAllObjects];
    return array;
}
- (NSDictionary *)linkRumKeysInfo{
    return [_linkRUMKeysInfo copy];
}
- (NSSet<NSNumber *> *)hiddenWebViewSlotIDs{
    return [_webViewSlotIDs copy];
}
@end


