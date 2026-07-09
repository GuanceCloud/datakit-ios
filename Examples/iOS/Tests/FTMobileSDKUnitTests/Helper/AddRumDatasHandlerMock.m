//
//  AddRumDatasHandlerMock.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/21.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

#import "AddRumDatasHandlerMock.h"
@implementation TestRUMData
-(instancetype)initWithType:(TestRUMType)type viewId:(NSString *)viewId{
    self = [super init];
    if(self){
        _type = type;
        _viewId = viewId;
    }
    return self;
}
@end
@implementation AddRumDatasHandlerMock
-(instancetype)init{
    self = [super init];
    if(self){
        _viewStartCount = 0;
        _viewStopCount = 0;
        _array = [NSMutableArray new];
    }
    return self;
}
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime{
    self.viewCreateCount++;
    self.lastCreateViewName = viewName;
    self.lastLoadTime = loadTime;
}
-(void)startViewWithName:(NSString *)viewName{
    _viewStartCount++;
}
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property{
    _viewStartCount++;
}
-(void)startViewWithViewID:(NSString *)viewId viewName:(NSString *)viewName property:(NSDictionary *)property{
    _viewStartCount++;
    self.lastStartViewName = viewName;
    self.lastStartProperty = property;
    [self.array addObject:[[TestRUMData alloc] initWithType:ViewStart viewId:viewId]];
}
-(void)stopView{
    _viewStopCount++;
}
-(void)stopViewWithProperty:(nullable NSDictionary *)property{
    _viewStopCount++;
}
-(void)stopViewWithViewID:(NSString *)viewId property:(NSDictionary *)property{
    _viewStopCount++;
    [self.array addObject:[[TestRUMData alloc] initWithType:ViewStop viewId:viewId]];
}
- (void)addAction:(nonnull NSString *)actionName actionType:(nonnull NSString *)actionType property:(nullable NSDictionary *)property {
    
}


- (void)addErrorWithType:(nonnull NSString *)type message:(nonnull NSString *)message stack:(nonnull NSString *)stack {
    
}


- (void)addErrorWithType:(nonnull NSString *)type message:(nonnull NSString *)message stack:(nonnull NSString *)stack property:(nullable NSDictionary *)property {
    
}


- (void)addErrorWithType:(nonnull NSString *)type state:(FTAppState)state message:(nonnull NSString *)message stack:(nonnull NSString *)stack property:(nullable NSDictionary *)property {
    
}


- (void)addLongTaskWithStack:(nonnull NSString *)stack duration:(nonnull NSNumber *)duration startTime:(long long)startTime {
    
}


- (void)addLongTaskWithStack:(nonnull NSString *)stack duration:(nonnull NSNumber *)duration startTime:(long long)startTime property:(nullable NSDictionary *)property {
    
}


- (void)startAction:(nonnull NSString *)actionName actionType:(nonnull NSString *)actionType property:(nullable NSDictionary *)property {
    self.actionStartCount++;
    self.lastActionName = actionName;
    self.lastActionType = actionType;
    self.lastActionProperty = property;
}
- (void)startAction:(nonnull NSString *)actionName actionType:(nonnull NSString *)actionType property:(nullable NSDictionary *)property heatmapAttributes:(nullable FTHeatmapAttributes *)heatmapAttributes {
    [self startAction:actionName actionType:actionType property:property];
    self.lastHeatmapAttributes = heatmapAttributes;
}
@end
