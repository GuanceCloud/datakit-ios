//
//  FTImageRequest.h
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/6.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTImageRequest : FTRequest
-(instancetype)initRequestWithFiles:(NSArray*)files parameters:(NSDictionary *)parameters;

@end

NS_ASSUME_NONNULL_END
