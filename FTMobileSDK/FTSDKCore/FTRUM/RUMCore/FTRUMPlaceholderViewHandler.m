//
//  FTRUMPlaceholderViewHandler.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/8/15.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTRUMPlaceholderViewHandler.h"
#import "FTRUMViewHandler.h"
#import "FTRUMActionHandler.h"
#import "FTRUMResourceHandler.h"
#import "FTConstants.h"
#import "NSDate+FTUtil.h"
#import "FTBaseInfoHandler.h"
#import "FTMonitorItem.h"
#import "FTMonitorValue.h"
#import "FTLog+Private.h"
#import "FTRUMContext.h"

@interface FTRUMPlaceholderViewHandler ()<FTRUMSessionProtocol>

@end
@implementation FTRUMPlaceholderViewHandler

- (void)writeViewData:(FTRUMDataModel *)model context:(NSDictionary *)context updateTime:(NSDate *)updateTime{
    
}

- (BOOL)process:(nonnull FTRUMDataModel *)model context:(nonnull NSDictionary *)context {
    return [super process:model context:context];
}

@end
