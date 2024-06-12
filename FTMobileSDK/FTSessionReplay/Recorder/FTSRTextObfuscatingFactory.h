//
//  FTSRTextObfuscatingFactory.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/12.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTRUMSessionReplay.h"
NS_ASSUME_NONNULL_BEGIN
@protocol FTSRTextObfuscatingProtocol <NSObject>

- (NSString *)mask:(NSString *)text;

@end
@interface FTSRTextObfuscatingFactory : NSObject
- (instancetype)initWithPrivacy:(FTSRPrivacy)privacy;
- (id<FTSRTextObfuscatingProtocol>)sensitiveTextObfuscator;
- (id<FTSRTextObfuscatingProtocol>)inputAndOptionTextObfuscator;
- (id<FTSRTextObfuscatingProtocol>)staticTextObfuscator;
- (id<FTSRTextObfuscatingProtocol>)hintTextObfuscator;
- (BOOL)shouldMaskInputElements;

@end

@interface FTNOPTextObfuscator : NSObject <FTSRTextObfuscatingProtocol>
@end
@interface FTFixLengthMaskObfuscator : NSObject<FTSRTextObfuscatingProtocol>

@end

@interface FTSpacePreservingMaskObfuscator : NSObject<FTSRTextObfuscatingProtocol>
@end
NS_ASSUME_NONNULL_END
