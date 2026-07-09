//
//  FTHeatmap.m
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

#import "FTHeatmap.h"
#import <CommonCrypto/CommonDigest.h>
#import <limits.h>
#import <math.h>
#import <string.h>

static long long FTHeatmapInt64FromCGFloat(CGFloat value) {
    if (!isfinite(value)) {
        return 0;
    }
    CGFloat roundedValue = round(value);
    if (roundedValue > LLONG_MAX) {
        return LLONG_MAX;
    }
    if (roundedValue < LLONG_MIN) {
        return LLONG_MIN;
    }
    return (long long)roundedValue;
}

@implementation FTHeatmapIdentifier
- (instancetype)initWithRawValue:(NSString *)rawValue {
    self = [super init];
    if (self) {
        _rawValue = [rawValue copy];
    }
    return self;
}
- (instancetype)initWithElementPath:(NSArray<NSString *> *)elementPath
                          viewName:(NSString *)viewName
                   bundleIdentifier:(NSString *)bundleIdentifier {
    NSMutableArray<NSString *> *canonicalPath = [NSMutableArray array];
    [canonicalPath addObject:bundleIdentifier.length > 0 ? bundleIdentifier : @"unknown"];
    [canonicalPath addObject:[NSString stringWithFormat:@"view:%@", viewName ?: @""]];
    [canonicalPath addObjectsFromArray:elementPath ?: @[]];
    NSString *rawPath = [canonicalPath componentsJoinedByString:@"/"];
    const char *input = [rawPath UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input, (CC_LONG)strlen(input), digest);
    NSMutableString *identifier = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [identifier appendFormat:@"%02x", digest[i]];
    }
    return [self initWithRawValue:identifier];
}
+ (NSValue *)objectIdentifierForObject:(id)object {
    return object ? [NSValue valueWithNonretainedObject:object] : nil;
}
- (id)copyWithZone:(NSZone *)zone {
    return [[FTHeatmapIdentifier allocWithZone:zone] initWithRawValue:self.rawValue];
}
- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:FTHeatmapIdentifier.class]) {
        return NO;
    }
    return [self.rawValue isEqualToString:((FTHeatmapIdentifier *)object).rawValue];
}
- (NSUInteger)hash {
    return self.rawValue.hash;
}
@end

@implementation FTHeatmapAttributes
- (instancetype)initWithIdentifier:(FTHeatmapIdentifier *)identifier
                              size:(CGSize)size
                          location:(CGPoint)location {
    self = [super init];
    if (self) {
        _targetPermanentID = [identifier.rawValue copy];
        _targetWidth = FTHeatmapInt64FromCGFloat(size.width);
        _targetHeight = FTHeatmapInt64FromCGFloat(size.height);
        _positionX = FTHeatmapInt64FromCGFloat(location.x);
        _positionY = FTHeatmapInt64FromCGFloat(location.y);
    }
    return self;
}
- (NSDictionary *)heatmapActionDictionary {
    if (self.targetPermanentID.length == 0) {
        return @{};
    }
    return @{
        @"action_position": @{
            @"x": @(self.positionX),
            @"y": @(self.positionY),
        },
        @"action_target": @{
            @"height": @(self.targetHeight),
            @"permanent_id": self.targetPermanentID,
            @"width": @(self.targetWidth),
        },
    };
}
@end
