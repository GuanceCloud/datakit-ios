//
//  FTResourceContentModel.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resource 数据内容
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
@property (nonatomic, strong,nullable) NSError *error;
/// 响应结果
@property (nonatomic, copy) NSString *responseBody;
///  初始化方法
/// - Parameters:
///   - request: 网络请求
///   - response: 网络请求响应结果
///   - data: 网络请求获得的数据
///   - error: error 信息
-(instancetype)initWithRequest:(NSURLRequest *)request response:(nullable NSHTTPURLResponse *)response data:(nullable NSData *)data error:(nullable NSError *)error;
@end

NS_ASSUME_NONNULL_END
