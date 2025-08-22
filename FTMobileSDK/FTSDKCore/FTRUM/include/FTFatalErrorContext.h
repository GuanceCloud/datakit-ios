//
//  FTFatalErrorContext.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/4/30.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
//Provide Session and View data for crash and longtask
@interface FTFatalErrorContext : NSObject

@property (atomic, copy) NSString *appState;

@property (atomic, strong) NSDictionary *lastSessionContext;

@property (atomic, strong, nullable) NSDictionary *lastViewContext;
@end

NS_ASSUME_NONNULL_END
