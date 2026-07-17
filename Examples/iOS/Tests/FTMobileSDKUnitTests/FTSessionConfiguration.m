//
//  FTSessionConfiguration.m
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/21.
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

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif
#import "FTSessionConfiguration.h"
#import <objc/runtime.h>
#import "FTURLProtocol.h"

@implementation FTSessionConfiguration
+ (FTSessionConfiguration *)defaultConfiguration {
    static FTSessionConfiguration *staticConfiguration;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        staticConfiguration=[[FTSessionConfiguration alloc] init];
    });
    return staticConfiguration;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _isExchanged = NO;
    }
    return self;
}
- (void)load {
    if (self.isExchanged) {
        return;
    }
    self.isExchanged=YES;
    Class cls = NSClassFromString(@"__NSCFURLSessionConfiguration") ?: NSClassFromString(@"NSURLSessionConfiguration");
    [self swizzleSelector:@selector(protocolClasses) fromClass:cls toClass:[self class]];
    
}
- (void)unload {
    if (!self.isExchanged) {
        return;
    }
    self.isExchanged=NO;
    Class cls = NSClassFromString(@"__NSCFURLSessionConfiguration") ?: NSClassFromString(@"NSURLSessionConfiguration");
    [self swizzleSelector:@selector(protocolClasses) fromClass:cls toClass:[self class]];
}
- (void)swizzleSelector:(SEL)selector fromClass:(Class)original toClass:(Class)stub {
    Method originalMethod = class_getInstanceMethod(original, selector);
    Method stubMethod = class_getInstanceMethod(stub, selector);
    if (!originalMethod || !stubMethod) {
        [NSException raise:NSInternalInconsistencyException format:@"Couldn't load NEURLSessionConfiguration."];
    }
    method_exchangeImplementations(originalMethod, stubMethod);
}

- (NSArray *)protocolClasses {
    // If there are other monitoring protocols, they can also be added here
    NSMutableArray *protocolClasses = [NSMutableArray array];
    // Keep OHHTTPStubs ahead of FTURLProtocol so stubbed tests never hit real network.
    Class httpStubsProtocolClass = NSClassFromString(@"OHHTTPStubsProtocol");
    if (httpStubsProtocolClass) {
        [protocolClasses addObject:httpStubsProtocolClass];
    }
    [protocolClasses addObject:[FTURLProtocol class]];
    return [protocolClasses copy];
}
@end
