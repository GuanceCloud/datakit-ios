//
//  FTHeatmap.h
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
