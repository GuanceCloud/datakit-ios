//
//  FTResourceContentModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTResourceContentModel : NSObject
/// 请求 url 
@property (nonatomic, strong) NSURL *url;
/// 请求头
@property (nonatomic, strong) NSDictionary *requestHeader;
/// 响应头
@property (nonatomic, strong) NSDictionary *responseHeader;
/// http 方法
@property (nonatomic, copy) NSString *httpMethod;
/// 请求结果状态码
@property (nonatomic, assign) NSInteger httpStatusCode;
/// 请求错误信息
@property (nonatomic, copy) NSString *errorMessage;
/// error 信息 （ios native）
@property (nonatomic, strong) NSError *error;
/// 响应结果
@property (nonatomic, copy) NSString *responseBody;
@end

NS_ASSUME_NONNULL_END
