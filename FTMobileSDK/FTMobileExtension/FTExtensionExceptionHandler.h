//
//  FTExtensionExceptionHandler.h
//  FTMobileExtension
//
//  Created by 胡蕾蕾 on 2020/11/16.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^FTExceptionHandlerBlock)(NSString *content,NSNumber *tm);

@interface FTExtensionExceptionHandler : NSObject
- (void)hookWithBlock:(FTExceptionHandlerBlock)callBack;
@end

NS_ASSUME_NONNULL_END
