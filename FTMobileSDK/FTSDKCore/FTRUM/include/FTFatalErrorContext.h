//
//  FTFatalErrorContext.h
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Provide Session and View data for crash and longtask
@interface FTFatalErrorContext : NSObject
// for long_task\anr
@property (atomic, copy) NSString *appState;
/// Session context (fallback when rum-view is nil, atomic)
@property (atomic, strong) NSDictionary *lastSessionContext;
/// View context (priority when rum-view exists, atomic, nullable)
@property (atomic, strong, nullable) NSDictionary *lastViewContext;
@end

NS_ASSUME_NONNULL_END
