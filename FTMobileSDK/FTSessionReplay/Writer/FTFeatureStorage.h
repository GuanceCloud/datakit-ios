//
//  FTDataStorage.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTWriter;
@interface FTFeatureStorage : NSObject
- (id<FTWriter>)writer;
- (void)clearAllData;
- (void)setIgnoreFilesAgeWhenReading:(BOOL)ignore;
@end

NS_ASSUME_NONNULL_END
