//
//  FTResourceContentModel.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/27.
//  Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTResourceContentModel.h"

typedef NS_ENUM(NSInteger, ResourceType) {
    ResourceTypeDocument,
    ResourceTypeXhr,
    ResourceTypeBeacon,
    ResourceTypeFetch,
    ResourceTypeCSS,
    ResourceTypeJS,
    ResourceTypeImage,
    ResourceTypeFont,
    ResourceTypeMedia,
    ResourceTypeOther,
    ResourceTypeNative
};

static inline NSString *ResourceTypeToString(ResourceType type) {
    switch (type) {
        case ResourceTypeDocument: return @"document";
        case ResourceTypeXhr: return @"xhr";
        case ResourceTypeBeacon: return @"beacon";
        case ResourceTypeFetch: return @"fetch";
        case ResourceTypeCSS: return @"css";
        case ResourceTypeJS: return @"js";
        case ResourceTypeImage: return @"image";
        case ResourceTypeFont: return @"font";
        case ResourceTypeMedia: return @"media";
        case ResourceTypeOther: return @"other";
        case ResourceTypeNative: return @"native";
    }
    return @"unknown";
}

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
        _responseBody = @"";
        _httpStatusCode = -1;
        _url = request.URL;
        _requestHeader = request.allHTTPHeaderFields;
        _httpMethod = request.HTTPMethod;
        if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            _responseHeader = httpResponse.allHeaderFields;
            _httpStatusCode = httpResponse.statusCode;
        }
        if (data && (error || _httpStatusCode >= 400)) {
            NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (responseBody) {
                _responseBody = responseBody;
            }
        }
        _error = error;
        _resourceType = [self resourceTypeWithRequest:request]?:[self resourceTypeWithResponse:response];
    }
    return self;
}
- (nullable NSString *)resourceTypeWithRequest:(NSURLRequest *)request{
    NSSet<NSString *> *nativeHTTPMethods = [NSSet setWithArray:@[@"POST",@"PUT",@"DELETE"]];
    if (request.HTTPMethod && [nativeHTTPMethods containsObject:[request.HTTPMethod uppercaseString]]) {
        return ResourceTypeToString(ResourceTypeNative);
    }
    return nil;
}
- (NSString *)resourceTypeWithResponse:(NSURLResponse *)response{
    NSString *mimeType = response.MIMEType;
    ResourceType type = ResourceTypeNative;
    if (mimeType && mimeType.length > 0) {
        NSArray<NSString *> *components = [mimeType componentsSeparatedByString:@"/"];
        
        NSString *mainType = [components.firstObject lowercaseString];
        NSString *subtypeComponent = components.lastObject;
        NSArray<NSString *> *subtypeParts = [subtypeComponent componentsSeparatedByString:@";"];
        NSString *subType = subtypeParts.firstObject ? [subtypeParts.firstObject lowercaseString] : @"";
    
        if ([mainType isEqualToString:@"image"]) {
            type = ResourceTypeImage;
        } else if ([mainType isEqualToString:@"video"] || [mainType isEqualToString:@"audio"]) {
            type = ResourceTypeMedia;
        } else if ([mainType isEqualToString:@"font"]) {
            type = ResourceTypeFont;
        } else if ([mainType isEqualToString:@"text"]) {
            if ([subType isEqualToString:@"css"]) {
                type = ResourceTypeCSS;
            } else if ([subType isEqualToString:@"javascript"]) {
                type = ResourceTypeJS;
            }
        }
    }
    return ResourceTypeToString(type);
}

@end
