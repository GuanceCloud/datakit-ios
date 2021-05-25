//
//  FTRUMScope.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMModel.h"

@class FTRUMScope;
NS_ASSUME_NONNULL_BEGIN
@protocol FTRUMScopeProtocol <NSObject>
- (BOOL)process:(FTRUMModel *)commond;
@optional
- (NSMutableArray<FTRUMScope*>*)manage:(NSMutableArray<FTRUMScope*> *)childScopes byPropagatingCommand:(FTRUMModel *)command;
@end
@interface FTRUMScope : NSObject
@property (nonatomic, weak) id<FTRUMScopeProtocol> assistant;
@end

NS_ASSUME_NONNULL_END
