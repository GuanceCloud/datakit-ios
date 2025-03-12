//
//  FTSRTextObfuscatingFactory.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRumSessionReplay.h"
typedef FTTextAndInputPrivacyLevel TextAndInputPrivacy;
NS_ASSUME_NONNULL_BEGIN
@protocol FTSRTextObfuscatingProtocol <NSObject>

- (NSString *)mask:(NSString *)text;

@end
@interface FTSRTextObfuscatingFactory : NSObject
+ (id<FTSRTextObfuscatingProtocol>)sensitiveTextObfuscator:(TextAndInputPrivacy)privacy;
+ (id<FTSRTextObfuscatingProtocol>)inputAndOptionTextObfuscator:(TextAndInputPrivacy)privacy;
+ (id<FTSRTextObfuscatingProtocol>)staticTextObfuscator:(TextAndInputPrivacy)privacy;
+ (id<FTSRTextObfuscatingProtocol>)hintTextObfuscator:(TextAndInputPrivacy)privacy;
+ (BOOL)shouldMaskInputElements:(TextAndInputPrivacy)privacy;

@end

@interface FTNOPTextObfuscator : NSObject <FTSRTextObfuscatingProtocol>
@end
@interface FTFixLengthMaskObfuscator : NSObject<FTSRTextObfuscatingProtocol>

@end

@interface FTSpacePreservingMaskObfuscator : NSObject<FTSRTextObfuscatingProtocol>
@end
NS_ASSUME_NONNULL_END
