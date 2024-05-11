//
//  FTFatalErrorContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
//为 crash 与 longtask 提供 Session、View 数据
@interface FTFatalErrorContext : NSObject

@property (atomic, copy) NSString *appState;

@property (atomic, strong) NSDictionary *lastSessionContext;

@property (atomic, strong) NSDictionary *lastViewContext;
@end

NS_ASSUME_NONNULL_END
