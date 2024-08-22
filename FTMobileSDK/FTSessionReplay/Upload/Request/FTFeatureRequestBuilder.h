//
//  FTFeatureRequestBuilder.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/28.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTFeatureRequestBuilder_h
#define FTFeatureRequestBuilder_h
#import <Foundation/Foundation.h>
@protocol FTRequestProtocol;
@protocol FTFeatureRequestBuilder <NSObject,FTRequestProtocol>
@optional
- (void)requestWithEvents:(NSArray *)events parameters:(NSDictionary *)parameters;
@end
#endif /* FTFeatureRequestBuilder_h */
