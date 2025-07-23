//
//  FTResourceContentModel.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTResourceContentModel.h"

@implementation FTResourceContentModel
-(instancetype)init{
    self = [super init];
    if (self) {
        self.httpMethod = @"";
        self.responseBody = @"";
        self.httpStatusCode = -1;
    }
    return self;
}
-(instancetype)initWithRequest:(NSURLRequest *)request response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error{
    self = [super init];
    if(self){
        _url = request.URL;
        _requestHeader = request.allHTTPHeaderFields;
        _httpMethod = request.HTTPMethod;
        if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            _responseHeader = httpResponse.allHeaderFields;
            _httpStatusCode = httpResponse.statusCode;
        }
        if (data) {
            _responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        _error = error;
    }
    return self;
}
@end

