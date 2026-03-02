//
//  FTRUMAction.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface FTRUMAction : NSObject

/// The RUM Action name
@property (nonatomic, copy) NSString *actionName;
/// The RUM Action extra property
@property (nonatomic, copy, nullable) NSDictionary *property;

/// Initialization method
/// - Parameter actionName: Set the RUM Action name
-(instancetype)initWithActionName:(NSString *)actionName;

/// Initialization method
/// - Parameters:
///   - actionName: Set the RUM Action name
///   - property: Set the RUM Action extra property
-(instancetype)initWithActionName:(NSString *)actionName property:(nullable NSDictionary *)property;
@end
NS_ASSUME_NONNULL_END
