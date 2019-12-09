//
//  ZYUploadTool.h
//  ft-sdk-ios
//
//  Created by 胡蕾蕾 on 2019/12/3.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ZYConfig;
NS_ASSUME_NONNULL_BEGIN

@interface ZYUploadTool : NSObject
@property (nonatomic, strong) ZYConfig *config;
-(void)upload;
@end

NS_ASSUME_NONNULL_END
