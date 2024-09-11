//
//  FTSRTextObfuscatingFactory.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSRTextObfuscatingFactory.h"
@interface FTSRTextObfuscatingFactory()
@property (nonatomic, assign) FTSRPrivacy privacy;
@end
@implementation FTSRTextObfuscatingFactory
-(instancetype)initWithPrivacy:(FTSRPrivacy)privacy{
    self = [super init];
    if(self){
        _privacy = privacy;
    }
    return self;
}
- (id<FTSRTextObfuscatingProtocol>)sensitiveTextObfuscator{
    
    return [FTFixLengthMaskObfuscator new];
}
- (id<FTSRTextObfuscatingProtocol>)inputAndOptionTextObfuscator{
    switch (self.privacy) {
        case FTSRPrivacyMaskNone:
            return [FTNOPTextObfuscator new];
            break;
        case FTSRPrivacyMaskOnlyInput:
            return [FTFixLengthMaskObfuscator new];
            break;
        case FTSRPrivacyMaskAllText:
            return [FTFixLengthMaskObfuscator new];
            break;
    }
}
- (id<FTSRTextObfuscatingProtocol>)staticTextObfuscator{
    switch (self.privacy) {
        case FTSRPrivacyMaskNone:
            return [FTNOPTextObfuscator new];
            break;
        case FTSRPrivacyMaskOnlyInput:
            return [FTNOPTextObfuscator new];
            break;
        case FTSRPrivacyMaskAllText:
            return [FTSpacePreservingMaskObfuscator new];
            break;
    }
}
- (id<FTSRTextObfuscatingProtocol>)hintTextObfuscator{
    switch (self.privacy) {
        case FTSRPrivacyMaskNone:
            return [FTNOPTextObfuscator new];
            break;
        case FTSRPrivacyMaskOnlyInput:
            return [FTNOPTextObfuscator new];
            break;
        case FTSRPrivacyMaskAllText:
            return [FTFixLengthMaskObfuscator new];
            break;
    }
}
- (BOOL)shouldMaskInputElements{
    switch (self.privacy) {
        case FTSRPrivacyMaskNone:
            return NO;
        case FTSRPrivacyMaskOnlyInput:
        case FTSRPrivacyMaskAllText:
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
