//
//  FTExtensionConfig.h
//  FTMobileExtension
//
//  Created by hulilei on 2022/10/17.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTExtensionConfig : NSObject

/// File sharing Group Identifier. (Required)
@property (nonatomic, copy) NSString *groupIdentifier;

/// Set whether to allow SDK to print Debug logs
@property (nonatomic, assign) BOOL enableSDKDebugLog;

/// Set whether to collect crash logs
@property (nonatomic, assign) BOOL enableTrackAppCrash;

/// Set whether to enable automatic collection of http Resource events in RUM
@property (nonatomic, assign) BOOL enableRUMAutoTraceResource;

/// Set whether to enable automatic http link tracing
@property (nonatomic, assign) BOOL enableTracerAutoTrace;

/// Maximum number of data items saved in Extension
///
/// Default 1000 items, delete old data and save new data when limit is reached
@property (nonatomic, assign) NSInteger memoryMaxCount;

/// Initialization method, set required parameter groupIdentifier
/// - Parameter groupIdentifier: File sharing Group Identifier
- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier;
@end

NS_ASSUME_NONNULL_END
