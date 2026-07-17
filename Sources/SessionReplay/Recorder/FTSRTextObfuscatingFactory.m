//
//  FTSRTextObfuscatingFactory.m
//  SessionReplay
//
//  Created by hulilei on 2024/6/12.
//
/*
 * This file is licensed under the Apache License Version 2.0.
 * This file contains software derived from software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 *
 * Modifications Copyright 2021 Shanghai Guance Information Technology Co., Ltd.
 * This file has been translated/adapted to Objective-C with project-specific changes.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTSRTextObfuscatingFactory.h"

@implementation FTSRTextObfuscatingFactory

+ (id<FTSRTextObfuscatingProtocol>)sensitiveTextObfuscator:(TextAndInputPrivacy)privacy{
    return [FTFixLengthMaskObfuscator new];
}
+ (id<FTSRTextObfuscatingProtocol>)inputAndOptionTextObfuscator:(TextAndInputPrivacy)privacy{
    switch (privacy) {
        case FTTextAndInputPrivacyLevelMaskSensitiveInputs:
            return [FTNOPTextObfuscator new];
            break;
        case FTTextAndInputPrivacyLevelMaskAllInputs:
            return [FTFixLengthMaskObfuscator new];
            break;
        case FTTextAndInputPrivacyLevelMaskAll:
            return [FTFixLengthMaskObfuscator new];
            break;
    }
}
+ (id<FTSRTextObfuscatingProtocol>)staticTextObfuscator:(TextAndInputPrivacy)privacy{
    switch (privacy) {
        case FTTextAndInputPrivacyLevelMaskSensitiveInputs:
            return [FTNOPTextObfuscator new];
            break;
        case FTTextAndInputPrivacyLevelMaskAllInputs:
            return [FTNOPTextObfuscator new];
            break;
        case FTTextAndInputPrivacyLevelMaskAll:
            return [FTSpacePreservingMaskObfuscator new];
            break;
    }
}
+ (id<FTSRTextObfuscatingProtocol>)hintTextObfuscator:(TextAndInputPrivacy)privacy{
    switch (privacy) {
        case FTTextAndInputPrivacyLevelMaskSensitiveInputs:
            return [FTNOPTextObfuscator new];
            break;
        case FTTextAndInputPrivacyLevelMaskAllInputs:
            return [FTNOPTextObfuscator new];
            break;
        case FTTextAndInputPrivacyLevelMaskAll:
            return [FTFixLengthMaskObfuscator new];
            break;
    }
}
+ (BOOL)shouldMaskInputElements:(TextAndInputPrivacy)privacy{
    switch (privacy) {
        case FTTextAndInputPrivacyLevelMaskSensitiveInputs:
            return NO;
        case FTTextAndInputPrivacyLevelMaskAllInputs:
        case FTTextAndInputPrivacyLevelMaskAll:
            return YES;
    }
}
@end

@implementation FTFixLengthMaskObfuscator

- (NSString *)mask:(nonnull NSString *)text {
    return @"***";
}

@end

@implementation FTNOPTextObfuscator

- (NSString *)mask:(NSString *)text{
    return text;
}

@end

@implementation FTSpacePreservingMaskObfuscator

-(NSString *)mask:(NSString *)text{
    NSMutableString *masked = [NSMutableString new];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar ch = [text characterAtIndex:i];
        if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
            [masked appendFormat:@"%c",ch];
        } else {
            [masked appendString:@"x"];
        }
    }
    return masked;
}
@end

#endif
