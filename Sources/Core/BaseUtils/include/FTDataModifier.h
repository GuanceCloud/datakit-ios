//
//  FTDataModifier.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/5/12.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#ifndef FTDataModifier_h
#define FTDataModifier_h

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

#endif
