//
//  FTSRTextObfuscatingFactory.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSRTextObfuscatingFactory.h"

@implementation FTSRTextObfuscatingFactory

+ (id<FTSRTextObfuscatingProtocol>)sensitiveTextObfuscator{
    
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
