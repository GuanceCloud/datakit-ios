//
//  FTWKWebViewHandler+SessionReplay.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/11/13.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTWKWebViewHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTWKWebViewHandler ()
/// Keys that allow association with RUM data
@property (nonatomic, copy) NSArray *enableLinkRUMKeys;
/// A collection of slotIds for webViews that exist in memory but are not displayed on the window
@property (nonatomic, readwrite, strong) NSSet<NSNumber *> *hiddenSlotIds;
/// Actively initiate a web session replay operation to obtain the full view, only applicable to webViews displayed on the window
- (void)takeSubsequentFullSnapshot;
/// Associate info with the RUM data of the corresponding viewId
/// Web -> Native RUM
- (void)bindInfo:(nullable NSDictionary *)info viewId:(NSString *)viewId;
@end

NS_ASSUME_NONNULL_END
