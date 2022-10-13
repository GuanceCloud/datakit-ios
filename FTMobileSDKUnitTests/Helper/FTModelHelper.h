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
+ (FTRecordModel *)createRumModel;
+ (FTRecordModel *)createWrongFormatRumModel;
+ (void)startView;
+ (void)stopView;
+ (void)addAction;
+ (void)addActionWithType:(NSString *)type;
@end

NS_ASSUME_NONNULL_END
