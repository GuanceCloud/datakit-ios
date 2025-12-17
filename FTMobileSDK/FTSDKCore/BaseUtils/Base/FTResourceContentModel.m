//
//  FTResourceContentModel.m
//  FTMobileAgent
//
//  Created by hulilei on 2021/10/27.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
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
NSString * const ResourceTypeStringMap[] = {
    [ResourceTypeDocument] = @"document",
    [ResourceTypeXhr] = @"xhr",
    [ResourceTypeBeacon] = @"beacon",
    [ResourceTypeFetch] = @"fetch",
    [ResourceTypeCSS] = @"css",
    [ResourceTypeJS] = @"js",
    [ResourceTypeImage] = @"image",
    [ResourceTypeFont] = @"font",
    [ResourceTypeMedia] = @"media",
    [ResourceTypeOther] = @"other",
    [ResourceTypeNative] = @"native",
};
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
        _resourceType = [self resourceTypeWithRequest:request]?:[self resourceTypeWithResponse:response];
    }
    return self;
}
- (nullable NSString *)resourceTypeWithRequest:(NSURLRequest *)request{
    NSSet<NSString *> *nativeHTTPMethods = [NSSet setWithArray:@[@"POST",@"PUT",@"DELETE"]];
    if (request.HTTPMethod && [nativeHTTPMethods containsObject:[request.HTTPMethod uppercaseString]]) {
        return ResourceTypeStringMap[ResourceTypeNative];
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
    return ResourceTypeStringMap[type];
}

@end

