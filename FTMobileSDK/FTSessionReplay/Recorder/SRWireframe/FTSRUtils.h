//
//  FTSRUtils.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/8.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
typedef enum FTSRPrivacy:NSUInteger FTSRPrivacy;

NS_ASSUME_NONNULL_BEGIN
CGRect FTCGRectFitWithContentMode(CGRect rect, CGSize size, UIViewContentMode mode);

@interface FTSRUtils : NSObject
+ (NSString *)colorHexString:(CGColorRef)color;
+ (NSString *)srPrivacyLabelString:(NSString *)string privacyType:(FTSRPrivacy)type;
+ (BOOL)isSensitiveText:(id<UITextInputTraits>)textInputTraits;
@end

NS_ASSUME_NONNULL_END
