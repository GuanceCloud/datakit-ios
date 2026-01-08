//
//  FTCrashReport.m
//
//  Created by Nikolay Volosatov on 2024-06-23.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "FTCrashReport.h"
#import "FTConstants.h"

#define REPORT_IMPL(NAME, TYPE)                                               \
    @implementation NAME                                                      \
                                                                              \
    +(instancetype)reportWithValue : (TYPE)value                              \
    {                                                                         \
        return [[NAME alloc] initWithValue:value];                            \
    }                                                                         \
                                                                              \
    -(instancetype)initWithValue : (TYPE)value                                \
    {                                                                         \
        self = [super init];                                                  \
        if (self != nil) {                                                    \
            _value = [value copy];                                            \
        }                                                                     \
        return self;                                                          \
    }                                                                         \
                                                                              \
    -(id)untypedValue                                                         \
    {                                                                         \
        return _value;                                                        \
    }                                                                         \
                                                                              \
    -(BOOL)isEqual : (id)object                                               \
    {                                                                         \
        if ([object isKindOfClass:[NAME class]] == NO) {                      \
            return NO;                                                        \
        }                                                                     \
        NAME *other = object;                                                 \
        return self.value == other.value || [self.value isEqual:other.value]; \
    }                                                                         \
                                                                              \
    -(NSString *)description                                                  \
    {                                                                         \
        return [self.value description];                                      \
    }                                                                         \
                                                                              \
    @end

@implementation RUMModel
- (instancetype)copyWithZone:(NSZone *)zone {
    RUMModel *model = [[[self class] allocWithZone:zone] init];
    model.source = self.source;
    model.tags = self.tags;
    model.fields = self.fields;
    model.createTime = self.createTime;
    return model;
}
@end

REPORT_IMPL(FTCrashReportDictionary, NSDictionary *)
REPORT_IMPL(FTCrashReportString, NSString *)
REPORT_IMPL(FTCrashReportData, NSData *)
REPORT_IMPL(FTCrashReportRUMModel, RUMModel *)
