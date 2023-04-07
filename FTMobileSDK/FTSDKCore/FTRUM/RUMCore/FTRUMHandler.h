//
//  FTRUMDataModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataModel.h"

@class FTRUMHandler;
NS_ASSUME_NONNULL_BEGIN
@protocol FTRUMSessionProtocol <NSObject>
- (BOOL)process:(FTRUMDataModel *)model;
@optional
- (NSMutableArray<FTRUMHandler*>*)manageChildHandlers:(NSMutableArray<FTRUMHandler*> *)childHandlers byPropagatingData:(FTRUMDataModel *)data;
- (FTRUMHandler *)manage:(FTRUMHandler *)childHandler byPropagatingData:(FTRUMDataModel *)data;

@end
@interface FTRUMHandler : NSObject
@property (nonatomic, weak) id<FTRUMSessionProtocol> assistant;
@end

NS_ASSUME_NONNULL_END
