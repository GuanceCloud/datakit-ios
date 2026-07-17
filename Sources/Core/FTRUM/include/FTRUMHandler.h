//
//  FTRUMHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/25.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
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
