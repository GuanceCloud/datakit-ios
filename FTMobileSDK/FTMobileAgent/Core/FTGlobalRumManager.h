//
//  FTGlobalRumManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMDataWriteProtocol.h"
NS_ASSUME_NONNULL_BEGIN
@class  FTRUMManager,FTRumConfig;

/// Class for managing RUM, used to enable collection of various RUM data
@interface FTGlobalRumManager : NSObject
/// Object for handling RUM data
@property (nonatomic, strong) FTRUMManager *rumManager;

/// Singleton
+ (instancetype)sharedInstance;

/// Set rum configuration options
/// - Parameter rumConfig: rum configuration options
- (void)setRumConfig:(FTRumConfig *)rumConfig writer:(id <FTRUMDataWriteProtocol>)writer;

/// Shut down singleton
- (void)shutDown;
@end

NS_ASSUME_NONNULL_END
