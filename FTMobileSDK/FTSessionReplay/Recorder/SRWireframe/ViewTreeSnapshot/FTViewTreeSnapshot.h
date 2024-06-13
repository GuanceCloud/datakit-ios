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
@protocol FTSRNodeSemantics <NSObject>
@property (nonatomic, assign) int importance;
@property (nonatomic, strong) NSArray<id<FTSRWireframesBuilder>> *nodes;
@property (nonatomic, strong) NSArray<id<FTSRResource>> *resources;
@property (nonatomic, assign) NodeSubtreeStrategy subtreeStrategy;
@end

@protocol FTSRWireframesBuilder;
@protocol FTSRResource;
@interface FTViewTreeSnapshot : NSObject
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) FTSRContext *context;
@property (nonatomic, assign) CGSize viewportSize;
@property (nonatomic, strong) NSArray<id<FTSRWireframesBuilder>> *nodes;
@property (nonatomic, strong) NSArray<id<FTSRResource>> *resources;

@end

@interface FTUnknownElement : NSObject<FTSRNodeSemantics>

@end
@interface FTInvisibleElement : NSObject<FTSRNodeSemantics>
+ (instancetype)constant;
@end
@interface FTIgnoredElement : NSObject<FTSRNodeSemantics>

@end

@interface FTAmbiguousElement : NSObject<FTSRNodeSemantics>

@end

@interface FTSpecificElement : NSObject<FTSRNodeSemantics>

@end
NS_ASSUME_NONNULL_END
