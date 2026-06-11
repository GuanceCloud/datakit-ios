//
//  FTHeatmap.h
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTHeatmapIdentifier : NSObject<NSCopying>
@property (nonatomic, copy, readonly) NSString *rawValue;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRawValue:(NSString *)rawValue NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithElementPath:(NSArray<NSString *> *)elementPath
                          viewName:(NSString *)viewName
                   bundleIdentifier:(NSString *)bundleIdentifier;
+ (nullable NSValue *)objectIdentifierForObject:(id)object;
@end

@interface FTHeatmapAttributes : NSObject
@property (nonatomic, copy, readonly) NSString *targetPermanentID;
@property (nonatomic, assign, readonly) long long targetWidth;
@property (nonatomic, assign, readonly) long long targetHeight;
@property (nonatomic, assign, readonly) long long positionX;
@property (nonatomic, assign, readonly) long long positionY;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(FTHeatmapIdentifier *)identifier
                              size:(CGSize)size
                          location:(CGPoint)location NS_DESIGNATED_INITIALIZER;
- (NSDictionary *)heatmapActionDictionary;
@end

@protocol FTHeatmapIdentifierRegistry <NSObject>
- (void)setHeatmapIdentifiers:(NSDictionary<NSValue *, FTHeatmapIdentifier *> *)heatmapIdentifiers;
- (nullable FTHeatmapIdentifier *)heatmapIdentifierForObject:(id)object;
- (BOOL)enableHeatmap;
- (void)setEnableHeatmap:(BOOL)enable;
@end

NS_ASSUME_NONNULL_END
