//
//  FTRUMView.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/23.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Parameters that describe a RUM view before it is recorded.
@interface FTRUMView : NSObject

/// The RUM View name
@property (nonatomic, copy) NSString *viewName;

/// The RUM View extra property
@property (nonatomic, copy, nullable) NSDictionary *property;

/// Whether this view is modal, but should not be tracked with `startView` and `stopView`

/// Differences from directly returning nil in the callback:
///  * When this is `true`, the view previous to this one will be stopped, but this one will not be started. When this view is dismissed, the previous view will be restarted.
///  * When the callback returns nil, the view previous to this one will not be stopped, and this one will not be started.
///
/// The reason is: When the modalPresentationStyle (modal presentation style) of a modal transition is not fullScreen, the original view controller will not call viewDidDisappear and viewDidAppear.
@property (nonatomic, assign) BOOL isUntrackedModal;

/// Initialization method
/// - Parameter viewName: Set the RUM View name
- (instancetype)initWithViewName:(NSString *)viewName;


/// Initialization method
/// - Parameters:
///   - viewName: Set the RUM View name
///   - property: Set the RUM View extra property
- (instancetype)initWithViewName:(NSString *)viewName property:(nullable NSDictionary *)property;
@end

NS_ASSUME_NONNULL_END
