//
//  FTModelHelper.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FTRecordModel.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTModelHelper : NSObject
+ (FTRecordModel *)createLogModel;
+ (FTRecordModel *)createLogModel:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
