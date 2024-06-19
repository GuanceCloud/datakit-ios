//
//  FTViewTreeSnapshot.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/13.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger,NodeSubtreeStrategy){
    NodeSubtreeStrategyRecord,
    NodeSubtreeStrategyIgnore
};

@protocol FTSRWireframesBuilder,FTSRResource;
@interface FTSRNodeSemantics : NSObject
@property (nonatomic, assign) int importance;
@property (nonatomic, strong) NSArray<id<FTSRWireframesBuilder>> *nodes;
@property (nonatomic, strong) NSArray<id<FTSRResource>> *resources;
@property (nonatomic, assign) NodeSubtreeStrategy subtreeStrategy;
-(instancetype)initWithSubtreeStrategy:(NodeSubtreeStrategy)subtreeStrategy;

@end

@protocol FTSRWireframesBuilder;
@protocol FTSRResource;
@class FTSRContext;
@interface FTViewTreeSnapshot : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) FTSRContext *context;
@property (nonatomic, assign) CGSize viewportSize;
@property (nonatomic, strong) NSArray<id<FTSRWireframesBuilder>> *nodes;
@property (nonatomic, strong) NSArray<id<FTSRResource>> *resources;
@end

@interface FTUnknownElement : FTSRNodeSemantics
+ (instancetype)constant;
@end
@interface FTInvisibleElement : FTSRNodeSemantics
+ (instancetype)constant;
@end
@interface FTIgnoredElement : FTSRNodeSemantics

@end

@interface FTAmbiguousElement : FTSRNodeSemantics

@end

@interface FTSpecificElement : FTSRNodeSemantics

@end
NS_ASSUME_NONNULL_END
