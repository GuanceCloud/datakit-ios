//
//  FTRUMResourceHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/26.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
@class FTRUMViewHandler;
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTResourceEventSent)(void);
//typedef void(^FTErrorEventSent)(void);

/// RUM Resource 数据处理者
@interface FTRUMResourceHandler : FTRUMHandler
/// resource 唯一标识
@property (nonatomic, copy,readonly) NSString *identifier;
/// rum 上下文
@property (nonatomic, strong) FTRUMContext *context;
/// resource 数据处理完毕回调
@property (nonatomic, copy) FTResourceEventSent resourceHandler;
//@property (nonatomic, copy) FTErrorEventSent errorHandler;
/// 初始化方法
/// - Parameters:
///   - model: rum数据模型
///   - context: rum 上下文
-(instancetype)initWithModel:(FTRUMResourceDataModel *)model context:(FTRUMContext *)context;
@end

NS_ASSUME_NONNULL_END
