//
//  FTFileLogger.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/3/6.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTLog+Private.h"
NS_ASSUME_NONNULL_BEGIN

@interface FTFileLogger : FTAbstractLogger
@property (nonatomic, copy,readonly) NSString *logFilePath;
-(instancetype)initWithFilePath:(nullable NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
