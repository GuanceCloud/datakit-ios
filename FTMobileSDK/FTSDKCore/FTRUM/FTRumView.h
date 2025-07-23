//
//  FTRumView.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/7/23.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTRumView : NSObject

/// The RUM View name
@property (nonatomic, copy) NSString *viewName;

/// The RUM View extra property
@property (nonatomic, copy) NSDictionary *property;

/// Whether this view is modal, but should not be tracked with `startView` and `stopView`
/// When this is `true`, the view previous to this one will be stopped, but this one will not be started.
/// When this view is dismissed, the previous view will be started.
@property (nonatomic, assign) BOOL isUntrackedModal;

@end

NS_ASSUME_NONNULL_END
