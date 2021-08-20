//
//  FTRequestBody.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTRecordModel;
NS_ASSUME_NONNULL_BEGIN
@protocol FTRequestBodyProtocol <NSObject>
- (NSString *)getRequestBodyWithEventArray:(NSArray *)events;
@end
@interface FTRequestBody : NSObject

@end
@interface FTRequestLineBody : NSObject<FTRequestBodyProtocol>
@property (nonatomic, strong) NSArray <FTRecordModel *> *events;

@end
@interface FTRequestObjectBody : NSObject<FTRequestBodyProtocol>
@property (nonatomic, strong) NSArray <FTRecordModel *> *events;

@end
NS_ASSUME_NONNULL_END
