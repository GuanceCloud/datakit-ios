//
//  FTResourceContentModel.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resource data content
@interface FTResourceContentModel : NSObject
/// Request URL 
@property (nonatomic, strong) NSURL *url;
/// Request headers
@property (nonatomic, strong) NSDictionary *requestHeader;
/// Response headers
@property (nonatomic, strong) NSDictionary *responseHeader;
/// HTTP method
@property (nonatomic, copy) NSString *httpMethod;
/// Request result status code
@property (nonatomic, assign) NSInteger httpStatusCode;
/// Request error message
@property (nonatomic, copy) NSString *errorMessage;
/// Error information (iOS native)
@property (nonatomic, strong,nullable) NSError *error;
/// Response result
@property (nonatomic, copy) NSString *responseBody;
///  Initialization method
/// - Parameters:
///   - request: network request
///   - response: network request response result
///   - data: data obtained from network request
///   - error: error information
-(instancetype)initWithRequest:(NSURLRequest *)request response:(nullable NSURLResponse *)response data:(nullable NSData *)data error:(nullable NSError *)error;
@end

NS_ASSUME_NONNULL_END
