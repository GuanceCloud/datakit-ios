//
//  FTRequestImageBody.h
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/6.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRequestBody.h"

NS_ASSUME_NONNULL_BEGIN
@protocol FTRequestImageBodyProtocol <NSObject>
- (NSData *)getRequestBodyWithImageDatas:(NSArray *)datas parameters:(NSDictionary *)parameters;
- (NSString *)boundary;
@end
@interface FTRequestImageBody : NSObject<FTRequestImageBodyProtocol>
@property (nonatomic, copy) NSString *boundary;

@end

NS_ASSUME_NONNULL_END
