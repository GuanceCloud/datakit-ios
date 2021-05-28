//
//  FTRUMScope.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/25.
//  Copyright © 2021 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMCommand.h"

@class FTRUMScope;
NS_ASSUME_NONNULL_BEGIN
@protocol FTRUMScopeProtocol <NSObject>
- (BOOL)process:(FTRUMCommand *)command;
@optional
- (NSMutableArray<FTRUMScope*>*)manageChildScopes:(NSMutableArray<FTRUMScope*> *)childScopes byPropagatingCommand:(FTRUMCommand *)command;
- (FTRUMScope *)manage:(FTRUMScope *)childScope byPropagatingCommand:(FTRUMCommand *)command;

@end
@interface FTRUMScope : NSObject
@property (nonatomic, weak) id<FTRUMScopeProtocol> assistant;
@end

NS_ASSUME_NONNULL_END
