//
//  FTRUMViewHandler.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/5/24.
//  Copyright © 2021 hll. All rights reserved.
//

#import "FTRUMHandler.h"
NS_ASSUME_NONNULL_BEGIN
typedef void(^FTErrorHandled)(void);

@class FTRUMMonitor,FTRUMContext;

@interface FTRUMViewHandler : FTRUMHandler<FTRUMSessionProtocol>
@property (nonatomic, strong,readonly) FTRUMContext *context;
@property (nonatomic, assign,readwrite) BOOL isActiveView;
@property (nonatomic, copy) NSString *view_id;
@property (nonatomic, copy) NSString *view_name;
@property (nonatomic, copy) NSString *view_referrer;
@property (nonatomic, strong) NSNumber *loading_time;

-(instancetype)initWithModel:(FTRUMViewModel *)model context:(FTRUMContext *)context rumDependencies:(FTRUMDependencies *)rumDependencies;

- (instancetype)initWithModel:(FTRUMViewModel *)model
                      context:(FTRUMContext *)context
              rumDependencies:(FTRUMDependencies *)rumDependencies
              needsMonitoring:(BOOL)needsMonitoring;
@end

NS_ASSUME_NONNULL_END
