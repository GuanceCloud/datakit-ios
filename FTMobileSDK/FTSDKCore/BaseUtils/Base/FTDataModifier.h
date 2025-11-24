//
//  FTDataModifier.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/5/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

/// Field replacement, suitable for global field replacement scenarios, if you expect line-by-line analysis to implement data replacement, please use FTLineDataModifier
/// - Parameters:
///   - key: field name
///   - value: field value (original value)
///   - return: new value, return original value if not modified; return nil to indicate no change
typedef id _Nullable(^FTDataModifier)(NSString * _Nonnull key,id _Nonnull value);


/// Can make judgments for a specific line, then decide whether to replace a certain value
/// Modification logic, only returns modified key-value pairs
/// - Parameters:
///   - measurement: measurement name
///   - data: merged key-value pairs
///   - return: modified key-value pairs (return nil or empty dictionary to indicate no change)
typedef NSDictionary<NSString *,id> *_Nullable (^FTLineDataModifier)(NSString * _Nonnull measurement,NSDictionary<NSString *,id> * _Nonnull data);
