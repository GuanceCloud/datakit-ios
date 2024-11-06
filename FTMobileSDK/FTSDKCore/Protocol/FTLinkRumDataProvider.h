//
//  FTLinkRumDataProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/10/14.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FTLinkRumDataProvider <NSObject>
-(NSDictionary *)getLinkRUMData;
@end

NS_ASSUME_NONNULL_END
