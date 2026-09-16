//
//  FTVisitorIDConfig.m
//  FTMobileSDK
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTVisitorIDConfig+Private.h"
#import "FTInnerLog.h"
#import <math.h>

static NSString * const FTVisitorIDConfigErrorDomain = @"com.guance.sdk.visitor-id-config";

typedef NS_ENUM(NSUInteger, FTVisitorIDMatcherType) {
    FTVisitorIDMatcherTypeURLPrefix,
    FTVisitorIDMatcherTypeRegularExpression,
    FTVisitorIDMatcherTypeHandler,
};

@interface FTVisitorIDMatcher : NSObject <NSCopying>
@property (nonatomic, assign) FTVisitorIDMatcherType type;
@property (nonatomic, copy, nullable) NSString *prefix;
@property (nonatomic, strong, nullable) NSRegularExpression *regularExpression;
@property (nonatomic, copy, nullable) FTVisitorIDURLMatchHandler handler;
@end

@implementation FTVisitorIDMatcher
- (id)copyWithZone:(NSZone *)zone {
    FTVisitorIDMatcher *copy = [[[self class] allocWithZone:zone] init];
    copy.type = self.type;
    copy.prefix = [self.prefix copy];
    copy.regularExpression = self.regularExpression;
    copy.handler = [self.handler copy];
    return copy;
}
@end

@interface FTVisitorIDConfig ()
@property (nonatomic, strong) NSMutableArray<FTVisitorIDMatcher *> *matchers;
@end

@implementation FTVisitorIDConfig

- (instancetype)init {
    self = [super init];
    if (self) {
        _ttlHours = 24;
        _matchers = [NSMutableArray array];
    }
    return self;
}

- (void)addMatchWithURLPrefix:(NSString *)prefix {
    FTVisitorIDMatcher *matcher = [FTVisitorIDMatcher new];
    matcher.type = FTVisitorIDMatcherTypeURLPrefix;
    matcher.prefix = [prefix copy];
    [self.matchers addObject:matcher];
}

- (void)addMatchWithRegularExpression:(NSRegularExpression *)regularExpression {
    FTVisitorIDMatcher *matcher = [FTVisitorIDMatcher new];
    matcher.type = FTVisitorIDMatcherTypeRegularExpression;
    matcher.regularExpression = regularExpression;
    [self.matchers addObject:matcher];
}

- (void)addMatchWithHandler:(FTVisitorIDURLMatchHandler)handler {
    FTVisitorIDMatcher *matcher = [FTVisitorIDMatcher new];
    matcher.type = FTVisitorIDMatcherTypeHandler;
    matcher.handler = [handler copy];
    [self.matchers addObject:matcher];
}

- (id)copyWithZone:(NSZone *)zone {
    FTVisitorIDConfig *copy = [[[self class] allocWithZone:zone] init];
    copy.header = [self.header copy];
    copy.ttlHours = self.ttlHours;
    copy.matchers = [[NSMutableArray alloc] initWithArray:self.matchers copyItems:YES];
    return copy;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    self = [self init];
    if (self) {
        if ([dictionary[@"header"] isKindOfClass:NSString.class]) {
            _header = [dictionary[@"header"] copy];
        }
        if ([dictionary[@"ttlHours"] isKindOfClass:NSNumber.class]) {
            _ttlHours = [dictionary[@"ttlHours"] doubleValue];
        }
        for (id value in [dictionary[@"urlPrefixes"] isKindOfClass:NSArray.class] ? dictionary[@"urlPrefixes"] : @[]) {
            if ([value isKindOfClass:NSString.class]) {
                [self addMatchWithURLPrefix:value];
            }
        }
        for (NSDictionary *entry in [dictionary[@"regularExpressions"] isKindOfClass:NSArray.class] ? dictionary[@"regularExpressions"] : @[]) {
            if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"pattern"] isKindOfClass:NSString.class]) {
                continue;
            }
            NSRegularExpressionOptions options = [entry[@"options"] isKindOfClass:NSNumber.class]
                ? [entry[@"options"] unsignedIntegerValue] : 0;
            NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:entry[@"pattern"]
                                                                                           options:options
                                                                                             error:nil];
            if (expression) {
                [self addMatchWithRegularExpression:expression];
            }
        }
    }
    return self;
}

- (NSDictionary *)convertToDictionary {
    NSMutableArray *prefixes = [NSMutableArray array];
    NSMutableArray *expressions = [NSMutableArray array];
    for (FTVisitorIDMatcher *matcher in self.matchers) {
        if (matcher.type == FTVisitorIDMatcherTypeURLPrefix && matcher.prefix) {
            [prefixes addObject:matcher.prefix];
        } else if (matcher.type == FTVisitorIDMatcherTypeRegularExpression && matcher.regularExpression) {
            [expressions addObject:@{
                @"pattern": matcher.regularExpression.pattern,
                @"options": @(matcher.regularExpression.options),
            }];
        }
    }
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:self.header forKey:@"header"];
    dictionary[@"ttlHours"] = @(self.ttlHours);
    dictionary[@"urlPrefixes"] = prefixes;
    dictionary[@"regularExpressions"] = expressions;
    return dictionary;
}

- (FTVisitorIDConfig *)validatedCopyWithError:(NSError **)error {
    NSString *reason = nil;
    if (![self validHeader:self.header]) {
        reason = @"Visitor ID header must be a lowercase custom HTTP token outside authentication, signature, Cookie, CSRF, and tracing headers";
    } else {
        double ttlSeconds = self.ttlHours * 60.0 * 60.0;
        if (!isfinite(self.ttlHours) || !isfinite(ttlSeconds) || ttlSeconds <= 0) {
            reason = @"Visitor ID TTL must be a positive, finite number of hours";
        } else if (self.matchers.count == 0) {
            reason = @"Visitor ID requires at least one URL matching rule";
        } else {
            for (FTVisitorIDMatcher *matcher in self.matchers) {
                if ((matcher.type == FTVisitorIDMatcherTypeURLPrefix && ![self validURLPrefix:matcher.prefix]) ||
                    (matcher.type == FTVisitorIDMatcherTypeRegularExpression && matcher.regularExpression == nil) ||
                    (matcher.type == FTVisitorIDMatcherTypeHandler && matcher.handler == nil)) {
                    reason = @"Visitor ID contains an empty or invalid URL matching rule";
                    break;
                }
            }
        }
    }
    if (reason) {
        if (error) {
            *error = [NSError errorWithDomain:FTVisitorIDConfigErrorDomain
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: reason}];
        }
        return nil;
    }
    return [self copy];
}

- (BOOL)matchesURL:(NSURL *)url {
    if (!url) {
        return NO;
    }
    NSString *scheme = url.scheme.lowercaseString;
    if (url.host.length == 0 ||
        !([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        return NO;
    }
    NSString *absoluteString = url.absoluteString;
    if (absoluteString.length == 0) {
        return NO;
    }
    for (FTVisitorIDMatcher *matcher in self.matchers) {
        @try {
            switch (matcher.type) {
                case FTVisitorIDMatcherTypeURLPrefix:
                    if ([absoluteString hasPrefix:matcher.prefix] &&
                        [self URL:url hasSameOriginAsURL:[NSURL URLWithString:matcher.prefix]]) {
                        return YES;
                    }
                    break;
                case FTVisitorIDMatcherTypeRegularExpression:
                    if ([matcher.regularExpression firstMatchInString:absoluteString
                                                               options:0
                                                                 range:NSMakeRange(0, absoluteString.length)]) {
                        return YES;
                    }
                    break;
                case FTVisitorIDMatcherTypeHandler:
                    if (matcher.handler(url)) {
                        return YES;
                    }
                    break;
            }
        } @catch (NSException *exception) {
            FTInnerLogWarning(@"Visitor ID URL matcher failed: %@", exception.reason);
        }
    }
    return NO;
}

- (BOOL)validURLPrefix:(NSString *)prefix {
    if (![prefix isKindOfClass:NSString.class] || prefix.length == 0) {
        return NO;
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:prefix];
    NSString *scheme = components.scheme.lowercaseString;
    return components.host.length > 0 &&
        ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]);
}

- (BOOL)URL:(NSURL *)first hasSameOriginAsURL:(NSURL *)second {
    if (!first || !second || first.host.length == 0 || second.host.length == 0) {
        return NO;
    }
    NSString *firstScheme = first.scheme.lowercaseString;
    NSString *secondScheme = second.scheme.lowercaseString;
    if (!([firstScheme isEqualToString:@"http"] || [firstScheme isEqualToString:@"https"]) ||
        ![firstScheme isEqualToString:secondScheme] ||
        [first.host caseInsensitiveCompare:second.host] != NSOrderedSame) {
        return NO;
    }
    NSInteger firstPort = first.port ? first.port.integerValue : ([firstScheme isEqualToString:@"https"] ? 443 : 80);
    NSInteger secondPort = second.port ? second.port.integerValue : ([secondScheme isEqualToString:@"https"] ? 443 : 80);
    return firstPort == secondPort;
}

- (BOOL)validHeader:(NSString *)header {
    if (![header isKindOfClass:NSString.class] || header.length == 0 ||
        [header rangeOfString:@"^[!#$%&'*+\\-.^_`|~0-9a-z]+$" options:NSRegularExpressionSearch].location == NSNotFound) {
        return NO;
    }
    for (NSString *prefix in @[@"proxy-", @"sec-", @"x-datadog-", @"x-b3-"]) {
        if ([header hasPrefix:prefix]) {
            return NO;
        }
    }
    for (NSString *fragment in @[@"authorization", @"authentication", @"api-key", @"api_key", @"apikey",
                                  @"auth-token", @"auth_token", @"access-token", @"access_token",
                                  @"session-token", @"session_token", @"refresh-token", @"refresh_token",
                                  @"id-token", @"id_token", @"security-token", @"security_token",
                                  @"csrf", @"xsrf", @"jwt", @"signature"]) {
        if ([header containsString:fragment]) {
            return NO;
        }
    }
    NSSet *reserved = [NSSet setWithArray:@[
        @"accept-charset", @"accept-encoding", @"access-control-request-headers",
        @"access-control-request-method", @"connection", @"content-length", @"cookie", @"cookie2",
        @"date", @"dnt", @"expect", @"host", @"keep-alive", @"origin", @"permissions-policy",
        @"referer", @"te", @"trailer", @"transfer-encoding", @"upgrade", @"via", @"b3",
        @"traceparent", @"tracestate", @"uber-trace-id", @"sw8", @"x-gc-trace-id",
        @"x-gc-span-id", @"x-rum-resource-id"
    ]];
    return ![reserved containsObject:header];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"{header = %@; ttlHours = %@; matcherCount = %@}",
            self.header ?: @"<nil>", @(self.ttlHours), @(self.matchers.count)];
}

@end
