//
//  FTRUMViewHandler.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTErrorHandled)(void);

@class FTRUMMonitor;
@interface FTRUMViewHandler : FTRUMHandler
@property (nonatomic, strong,readonly) FTRUMContext *context;
@property (nonatomic, assign,readwrite) BOOL isActiveView;
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, strong) NSNumber *loading_time;
/// 当前 view 处理了 error 数据回调
@property (nonatomic, copy) FTErrorHandled errorHandled;

-(instancetype)initWithModel:(FTRUMViewModel *)model context:(FTRUMContext *)context monitor:(FTRUMMonitor *)monitor;
@end

NS_ASSUME_NONNULL_END
