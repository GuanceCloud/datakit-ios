//
//  FTCoreDirectory.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/6/4.
//  Copyright © 2026 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FTDirectory,FTFeatureDirectories;
NS_ASSUME_NONNULL_BEGIN

@interface FTCoreDirectory : NSObject
@property (nonatomic, strong, readonly) FTDirectory *directory;

- (instancetype)initWithDirectory:(FTDirectory *)directory;
- (instancetype)initWithSubdirectoryPath:(NSString *)path;
- (nullable FTFeatureDirectories *)featureDirectoriesForFeatureName:(NSString *)featureName;
@end

NS_ASSUME_NONNULL_END
