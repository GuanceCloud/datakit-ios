//
//  FTRUMDataModel.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDependencies.h"
#import "FTRUMDataModel.h"

@class FTRUMHandler;
NS_ASSUME_NONNULL_BEGIN
@protocol FTRUMSessionProtocol <NSObject>
- (BOOL)process:(FTRUMDataModel *)model context:(NSDictionary *)context;
@optional
- (NSMutableArray<FTRUMHandler*>*)manageChildHandlers:(NSMutableArray<FTRUMHandler*> *)childHandlers byPropagatingData:(FTRUMDataModel *)data context:(NSDictionary *)context;
- (FTRUMHandler *)manage:(FTRUMHandler *)childHandler byPropagatingData:(FTRUMDataModel *)data context:(NSDictionary *)context;

@end
@interface FTRUMHandler : NSObject
@property (nonatomic, weak, nullable) id<FTRUMSessionProtocol> assistant;
@end

NS_ASSUME_NONNULL_END
