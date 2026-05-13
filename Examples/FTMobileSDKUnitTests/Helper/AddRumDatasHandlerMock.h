//
//  AddRumDatasHandlerMock.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2025/2/21.
//  Copyright © 2025 GuanceCloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRumDatasProtocol.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, TestRUMType) {
    ViewStart,
    ViewStop,
};

@interface TestRUMData: NSObject
@property (nonatomic, assign) TestRUMType type;
@property (nonatomic, copy) NSString *viewId;
@end

@interface AddRumDatasHandlerMock : NSObject<FTRumDatasProtocol>
@property (nonatomic, assign) NSInteger viewStartCount;
@property (nonatomic, assign) NSInteger viewStopCount;
@property (nonatomic, strong) NSMutableArray<TestRUMData *> *array;
@property (nonatomic, assign) NSInteger viewCreateCount;
@property (nonatomic, copy, nullable) NSString *lastCreateViewName;
@property (nonatomic, strong, nullable) NSNumber *lastLoadTime;
@property (nonatomic, copy, nullable) NSString *lastStartViewName;
@property (nonatomic, copy, nullable) NSDictionary *lastStartProperty;
@property (nonatomic, assign) NSInteger actionStartCount;
@property (nonatomic, copy, nullable) NSString *lastActionName;
@property (nonatomic, copy, nullable) NSString *lastActionType;
@property (nonatomic, copy, nullable) NSDictionary *lastActionProperty;
@end

NS_ASSUME_NONNULL_END
