//
//  FTRequestBody.h
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/5.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTRecordModel;
NS_ASSUME_NONNULL_BEGIN
@protocol FTRequestBodyProtocol <NSObject>
- (NSString *)getRequestBodyWithEventArray:(NSArray *)events packageId:(NSString *)packageId enableIntegerCompatible:(BOOL)compatible;
@end
@interface FTRequestBody : NSObject

@end
@interface FTRequestLineBody : NSObject<FTRequestBodyProtocol>
@property (nonatomic, strong) NSArray <FTRecordModel *> *events;

@end
NS_ASSUME_NONNULL_END
