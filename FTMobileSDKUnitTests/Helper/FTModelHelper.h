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
+ (void)startView:(NSDictionary *)context;
+ (void)stopView;
+ (void)stopView:(NSDictionary *)context;
+ (void)addAction;
+ (void)addActionWithType:(NSString *)type;
+ (void)addActionWithContext:(NSDictionary *)context;
@end

NS_ASSUME_NONNULL_END
